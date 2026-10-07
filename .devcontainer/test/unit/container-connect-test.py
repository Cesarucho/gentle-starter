"""Local PTY fixtures; no real socket paths, remote commands, or host state."""
import errno
import os
from pathlib import Path
import pty
import selectors
import subprocess
import tempfile
import signal
import sys
import time


class PtyTimeout(subprocess.TimeoutExpired):
    def __init__(self, command, timeout, output, process):
        super().__init__(command, timeout, output=output)
        self.pid = process.pid
        self.returncode = process.returncode


def run_pty(command, environment, timeout: float = 5):
    master, slave = pty.openpty()
    process = None
    output = bytearray()
    deadline = time.monotonic() + timeout
    try:
        process = subprocess.Popen(command, env=environment, stdin=slave,
                                   stdout=slave, stderr=slave)
        os.close(slave)
        slave = None
        os.set_blocking(master, False)
        with selectors.DefaultSelector() as selector:
            selector.register(master, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    raise subprocess.TimeoutExpired(command, timeout)
                try:
                    chunk = os.read(master, 65536)
                except BlockingIOError:
                    continue
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    break
                if not chunk:
                    break
                output.extend(chunk)
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise subprocess.TimeoutExpired(command, timeout)
        assert process.wait(timeout=remaining) == 0
        return output.decode()
    except BaseException as error:
        if process is not None:
            process.terminate()
            try:
                process.wait(timeout=0.25)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=1)
            if isinstance(error, subprocess.TimeoutExpired):
                raise PtyTimeout(command, timeout, bytes(output), process) from error
        raise
    finally:
        os.close(master)
        if slave is not None:
            os.close(slave)


def test_pty_timeout():
    # Ignore TERM so the fixture also proves bounded KILL escalation and reaping.
    command = [sys.executable, "-c",
               'import os, signal; signal.signal(signal.SIGTERM, signal.SIG_IGN); '
               'print(os.getpid(), flush=True); signal.pause()']
    started = time.monotonic()
    try:
        run_pty(command, os.environ, timeout=0.5)
    except PtyTimeout as error:
        elapsed = time.monotonic() - started
        pid = int(error.output.strip())
        assert error.pid == pid
        assert error.returncode == -signal.SIGKILL
        assert 0.5 <= elapsed < 3, elapsed
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError(f"Timed-out child {pid} is still alive")
        try:
            os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            pass
        else:
            raise AssertionError(f"Timed-out child {pid} was not reaped")
        print(f"PASS: PTY timeout elapsed={elapsed:.3f}s pid={pid} "
              "SIGKILL reaped; alive=false; no waitable child")
    else:
        raise AssertionError("Hanging PTY child did not time out")

ROOT = Path(__file__).resolve().parents[3]
test_pty_timeout()
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    home = root / "home"
    home.mkdir()
    (home / ".ssh").mkdir()
    (home / ".bashrc").write_text('export BASHRC_PRESERVED=yes\n')
    source = (ROOT / ".taskfiles/scripts/container-connect.bash").read_text()
    # Redirect the fixed endpoint to a fixture socket; production remains /ssh-agent.
    import socket
    endpoint = root / "agent"
    sock = socket.socket(socket.AF_UNIX)
    sock.bind(str(endpoint))
    rcfile = root / "rcfile"
    rcfile.write_text(source.replace('/ssh-agent', str(endpoint)))
    bin_dir = root / "bin"
    bin_dir.mkdir()
    calls = root / "calls"
    for name in ("ssh", "ssh-add", "ssh-keyscan", "docker", "curl", "wget"):
        shim = bin_dir / name
        shim.write_text(f'#!/bin/bash\nprintf forbidden >>"{calls}"\nexit 99\n')
        shim.chmod(0o755)
    shim = bin_dir / "python3"
    welcome_checks = root / "welcome-checks"
    shim.write_text(f'#!/bin/bash\nprintf manifest >>"{welcome_checks}"\n'
                    'exit "${MANIFEST_STATUS:-0}"\n')
    shim.chmod(0o755)
    for name in ("bash", "dirname"):
        (bin_dir / name).symlink_to(Path("/usr/bin") / name)
    environment = {**os.environ, "HOME": str(home), "PATH": f"{bin_dir}:{os.environ['PATH']}",
                   "SSH_AUTH_SOCK": str(endpoint)}
    environment.pop("WELCOME_LOG_LEVEL", None)

    def execute(tty=True, **extra):
        command = ["/usr/bin/bash", "--rcfile", str(rcfile), "-i", "-c",
                   'printf "bashrc:%s\\n" "$BASHRC_PRESERVED"; bash -c "printf nested-ok"']
        if not tty:
            return subprocess.run(command, env={**environment, **extra}, capture_output=True).stdout.decode()
        return run_pty(command, {**environment, **extra})

    assert "Welcome" not in execute(False)
    missing = execute()
    assert "StrictHostKeyChecking=ask" in missing and "bashrc:yes" in missing
    assert missing.count("Welcome") == 1 and "nested-ok" in missing
    assert execute(WELCOME_LOG_LEVEL="info") == missing
    warnings = execute(WELCOME_LOG_LEVEL="warn")
    assert "[info]" not in warnings and "[warn] GitHub host trust is missing." in warnings
    assert "StrictHostKeyChecking=ask" in warnings and "https://docs.github.com/" in warnings
    for invalid in ("", "invalid", "INFO", " warn "):
        output = execute(WELCOME_LOG_LEVEL=invalid)
        assert output.count("[warn] Invalid WELCOME_LOG_LEVEL") == 1
        assert "[info] Welcome" in output and "StrictHostKeyChecking=ask" in output
        assert "bashrc:yes" in output and "nested-ok" in output
    welcome_checks.unlink()
    output = execute(WELCOME_LOG_LEVEL="off")
    assert "[info]" not in output and "[warn]" not in output
    assert "StrictHostKeyChecking" not in output and "https://" not in output
    assert "bashrc:yes" in output and "nested-ok" in output
    assert not welcome_checks.exists()
    for invalid in ("", "invalid"):
        output = execute(False, WELCOME_LOG_LEVEL=invalid)
        assert "[warn]" not in output and "[info]" not in output
        assert "bashrc:yes" in output and "nested-ok" in output
        assert not welcome_checks.exists()
    assert "unavailable" in execute(MANIFEST_STATUS="1")
    assert "expected local agent" in execute(SSH_AUTH_SOCK="wrong")
    known = home / ".ssh/known_hosts"
    known.write_text("github.com ssh-ed25519 AAAA\n")
    before = known.read_bytes()
    output = execute(PATH=str(bin_dir))
    assert "[warn] GitHub known_hosts lookup unavailable: ssh-keygen command not found." in output
    assert "bashrc:yes" in output and "nested-ok" in output
    assert known.read_bytes() == before and not calls.exists()
    assert "[info] Welcome to Gentle Starter." in missing
    assert "[info] Agent socket exists;" in missing
    assert "[warn] GitHub host trust is missing." in missing
    assert "[warn] SSH onboarding unavailable:" in execute(MANIFEST_STATUS="1")
    assert "[warn] SSH onboarding unavailable:" in execute(SSH_AUTH_SOCK="wrong")
    known.unlink()
    known.mkdir()
    assert "[warn] GitHub known_hosts lookup unavailable;" in execute(PATH=str(bin_dir))
    known.rmdir()
    shim = bin_dir / "ssh-keygen"
    shim.write_text('#!/bin/bash\nprintf "%s\\n" "$LOOKUP_OUTPUT"\nexit "${LOOKUP_STATUS:-0}"\n')
    shim.chmod(0o755)
    known.write_text("fixture trust file\n")
    before = known.read_bytes()
    scenarios = [
        ("github.com ssh-ed25519 AAAA\ngithub.com ssh-rsa BBBB", False, False),
        ("github.com ssh-ed25519 AAAA\ngithub.com ssh-ed25519 AAAA comment", False, False),
        ("github.com ssh-ed25519 AAAA\ngithub.com ssh-rsa BBBB\ngithub.com ssh-ed25519 CCCC", True, False),
        ("@revoked github.com ssh-ed25519 AAAA\ngithub.com ssh-rsa BBBB", False, True),
    ]
    for records, conflict, revoked in scenarios:
        output = execute(PATH=str(bin_dir), LOOKUP_OUTPUT=records)
        assert "[info] GitHub known_hosts entry present;" in output
        assert ("[warn] multiple differing GitHub records;" in output) == conflict
        assert ("[warn] revoked GitHub entry;" in output) == revoked
        assert "WARNING:" not in output
        assert known.read_bytes() == before and not calls.exists()
        warnings = execute(PATH=str(bin_dir), LOOKUP_OUTPUT=records, WELCOME_LOG_LEVEL="warn")
        assert "[info]" not in warnings
        assert ("[warn] multiple differing GitHub records;" in warnings) == conflict
        assert ("[warn] revoked GitHub entry;" in warnings) == revoked
    welcome_checks.unlink()
    assert "[warn]" not in execute(PATH=str(bin_dir), WELCOME_LOG_LEVEL="off")
    assert not welcome_checks.exists() and known.read_bytes() == before
    assert "[warn] GitHub known_hosts lookup failed;" in execute(
        PATH=str(bin_dir), LOOKUP_STATUS="2")
    print("PASS: hermetic severity, missing-command, file validity and fake lookup branches")
    shim.unlink()
    if not Path("/usr/bin/ssh-keygen").is_file():
        sock.close()
        print("SKIP: real ssh-keygen plain/hashed parser proof; /usr/bin/ssh-keygen unavailable")
        sys.exit(0)
    # A generated local public key gives the real ssh-keygen parser valid input.
    subprocess.run(["/usr/bin/ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(root / "key")], check=True)
    public = (root / "key.pub").read_text().split()
    entry = "github.com " + " ".join(public[:2]) + "\n"
    for hashed in (False, True):
        known.write_text(entry)
        if hashed:
            subprocess.run(["/usr/bin/ssh-keygen", "-H", "-f", str(known)], capture_output=True, check=True)
        before = known.read_bytes()
        output = execute()
        assert "presence does not establish valid trust" in output
        assert public[1] not in output and known.read_bytes() == before
    known.write_text("@revoked " + entry + entry.replace(public[1], "AAAA"))
    output = execute()
    assert "revoked GitHub" in output and "possible conflicts" in output
    keys = [public[:2]]
    for name, algorithm in (("rsa", "rsa"), ("ecdsa", "ecdsa"),
                            ("other-ed25519", "ed25519")):
        key = root / name
        subprocess.run(["/usr/bin/ssh-keygen", "-q", "-t", algorithm,
                        "-N", "", "-f", str(key)], env=environment, check=True)
        keys.append(Path(str(key) + ".pub").read_text().split()[:2])
    records = ["github.com " + " ".join(key) for key in keys]
    scenarios = [
        ("mixed algorithms", records[:3], False, False),
        ("reordered algorithms", list(reversed(records[:3])), False, False),
        ("commented duplicates", [records[0] + " first comment", records[1],
                                 records[0] + " different comment", records[2],
                                 records[1] + " duplicate", records[2]], False, False),
        ("interleaved same-type conflict", [records[0], records[1], records[3],
                                            records[2], records[0]], True, False),
        ("independent revocation", [records[0], records[1],
                                    "@revoked " + records[2]], False, True),
    ]
    for hashed in (False, True):
        for label, entries, conflict, revoked in scenarios:
            known.write_text("\n".join(entries) + "\n")
            if hashed:
                subprocess.run(["/usr/bin/ssh-keygen", "-H", "-f", str(known)],
                               env=environment, capture_output=True, check=True)
            before = known.read_bytes()
            output = execute()
            assert ("possible conflicts" in output) == conflict, (label, hashed)
            assert ("revoked GitHub" in output) == revoked, (label, hashed)
            assert "presence does not establish valid trust" in output
            assert all(key[1] not in output for key in keys)
            assert known.read_bytes() == before
            assert "bashrc:yes" in output and "nested-ok" in output
            assert not calls.exists()
    print("PASS: 10 plain/hashed algorithm, duplicate, conflict and revocation cases")
    shim = bin_dir / "ssh-keygen"
    shim.write_text('#!/bin/bash\nexit 2\n')
    shim.chmod(0o755)
    assert "lookup failed" in execute()
    assert not calls.exists()
    assert (home / ".bashrc").read_text() == 'export BASHRC_PRESERVED=yes\n'
    sock.close()
print("PASS: local PTY, gating, bashrc, plain/hashed/revoked/conflict/error and forbidden calls")
