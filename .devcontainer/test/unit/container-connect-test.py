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
    shim.write_text('#!/bin/bash\nexit "${MANIFEST_STATUS:-0}"\n')
    shim.chmod(0o755)
    environment = {**os.environ, "HOME": str(home), "PATH": f"{bin_dir}:{os.environ['PATH']}",
                   "SSH_AUTH_SOCK": str(endpoint)}

    def execute(tty=True, **extra):
        command = ["bash", "--rcfile", str(rcfile), "-i", "-c",
                   'printf "bashrc:%s\\n" "$BASHRC_PRESERVED"; bash -c "printf nested-ok"']
        if not tty:
            return subprocess.run(command, env={**environment, **extra}, capture_output=True).stdout.decode()
        return run_pty(command, {**environment, **extra})

    assert "Welcome" not in execute(False)
    missing = execute()
    assert "StrictHostKeyChecking=ask" in missing and "bashrc:yes" in missing
    assert missing.count("Welcome") == 1 and "nested-ok" in missing
    assert "unavailable" in execute(MANIFEST_STATUS="1")
    assert "expected local agent" in execute(SSH_AUTH_SOCK="wrong")
    known = home / ".ssh/known_hosts"
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
    shim = bin_dir / "ssh-keygen"
    shim.write_text('#!/bin/bash\nexit 2\n')
    shim.chmod(0o755)
    assert "lookup failed" in execute()
    assert not calls.exists()
    assert (home / ".bashrc").read_text() == 'export BASHRC_PRESERVED=yes\n'
    sock.close()
print("PASS: local PTY, gating, bashrc, plain/hashed/revoked/conflict/error and forbidden calls")
