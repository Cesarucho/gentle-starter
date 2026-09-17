#!/usr/bin/env python3
"""Attach locally, supervising only the OpenCode server started by this invocation."""

import base64
from contextlib import contextmanager
import errno
import fcntl
import http.client
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ENDPOINT = "http://127.0.0.1:4096"
START_TIMEOUT = 20
LOCK_TIMEOUT = 25
STOP_TIMEOUT = 3
POLL_INTERVAL = 0.1
STARTUP_GUIDANCE = (
    "Run `opencode serve` manually in the same container and workspace "
    "to inspect startup diagnostics."
)


class TransientHealthError(RuntimeError):
    """Retryable only after this invocation owns the startup listener."""


def transport_failure(error):
    while isinstance(error, urllib.error.URLError):
        error = error.reason
    # RemoteDisconnected is both an OSError and a BadStatusLine subclass.
    if isinstance(error, (http.client.RemoteDisconnected, http.client.IncompleteRead)):
        raise TransientHealthError("OpenCode health check HTTP response interrupted.") from None
    if isinstance(error, http.client.HTTPException):
        raise RuntimeError("Endpoint returned an invalid HTTP health response.") from None
    if isinstance(error, TimeoutError) or getattr(error, "errno", None) == errno.ETIMEDOUT:
        raise TransientHealthError("OpenCode health check timed out.") from None
    if getattr(error, "errno", None) == errno.ECONNREFUSED:
        return False
    if getattr(error, "errno", None) in (errno.ECONNRESET, errno.ECONNABORTED, errno.EPIPE):
        raise TransientHealthError("OpenCode health check transport interrupted.") from None
    raise RuntimeError("OpenCode health check transport failed; refusing replacement.") from None


@contextmanager
def health_deadline():
    # Socket timeouts alone do not bound a peer that continuously trickles bytes.
    def expired(_signum, _frame):
        raise TimeoutError

    previous = signal.signal(signal.SIGALRM, expired)
    signal.setitimer(signal.ITIMER_REAL, 2)
    try:
        yield
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous)


def healthy():
    request = urllib.request.Request(ENDPOINT + "/global/health")
    password = os.environ.get("OPENCODE_SERVER_PASSWORD", "")
    if password:
        username = os.environ.get("OPENCODE_SERVER_USERNAME") or "opencode"
        token = base64.b64encode(f"{username}:{password}".encode()).decode()
        request.add_header("Authorization", "Basic " + token)
    # Never send local credentials through a proxy or follow a redirect.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None

    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with health_deadline(), opener.open(request, timeout=1) as response:
            body = json.loads(response.read(65536))
            if (
                response.status == 200 and isinstance(body, dict)
                and body.get("healthy") is True
                and isinstance(body.get("version"), str) and body["version"]
            ):
                return True
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            raise RuntimeError("Endpoint rejected health check authentication (HTTP 401/403).") from None
        raise RuntimeError(f"Endpoint rejected the health check (HTTP {error.code}).") from None
    except (urllib.error.URLError, OSError, http.client.HTTPException) as error:
        return transport_failure(error)
    except ValueError:
        raise RuntimeError("Endpoint returned invalid JSON in the OpenCode health response.") from None
    raise RuntimeError("Endpoint returned an invalid OpenCode health response schema or status.")


def print_browser_address():
    port = os.environ.get("OPENCODE_PORT", "")
    if not (port and len(port) <= 5 and port.isascii() and port.isdigit()
            and 1 <= int(port) <= 65535):
        print("[opencode-server] Warning: OPENCODE_PORT is missing or invalid; "
              "host browser address unavailable. Attaching anyway.", file=sys.stderr, flush=True)
        return
    print(f"[opencode-server] Host browser address: http://localhost:{int(port)}/ "
          "(from another device on the same network, replace localhost with the host LAN/WLAN IP).",
          flush=True)


def owns_listener(pid):
    """Do not mistake an unrelated racing listener for our successfully started child."""
    try:
        sockets = {entry.readlink().name for entry in Path(f"/proc/{pid}/fd").iterdir()}
        for table, addresses in (
            ("tcp", {"00000000:1000", "0100007F:1000"}),
            ("tcp6", {"00000000000000000000000000000000:1000"}),
        ):
            for line in Path(f"/proc/{pid}/net/{table}").read_text().splitlines()[1:]:
                fields = line.split()
                if fields[1] in addresses and fields[3] == "0A":
                    if f"socket:[{fields[9]}]" in sockets:
                        return True
    except (OSError, IndexError):
        return False
    return False


def stop(child):
    if child is None or child.poll() is not None:
        return
    try:
        child.terminate()
    except ProcessLookupError:
        child.wait(timeout=STOP_TIMEOUT)
        return
    try:
        child.wait(timeout=STOP_TIMEOUT)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait(timeout=STOP_TIMEOUT)


class Session:
    def __init__(self):
        self.signal = 0
        self.server = None
        self.client = None

    def interrupted(self, signum, _frame):
        # Defer cleanup until Popen has returned and ownership is recorded.
        self.signal = signum

    def check_signal(self):
        if self.signal:
            raise InterruptedError

    def acquire_lock(self, descriptor):
        deadline = time.monotonic() + LOCK_TIMEOUT
        while time.monotonic() < deadline:
            self.check_signal()
            try:
                fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return
            except BlockingIOError:
                time.sleep(POLL_INTERVAL)
        raise RuntimeError("Timed out waiting for another OpenCode startup.")

    def start(self):
        self.check_signal()
        if healthy():
            return
        self.check_signal()
        self.server = subprocess.Popen(
            ["opencode", "serve"], stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
        deadline = time.monotonic() + START_TIMEOUT
        last_failure = "Owned listener not available."
        while time.monotonic() < deadline:
            self.check_signal()
            code = self.server.poll()
            if code is not None:
                reason = f"signal {-code}" if code < 0 else f"exit code {code}"
                raise RuntimeError(
                    f"Owned OpenCode server exited before becoming ready ({reason}). {STARTUP_GUIDANCE}"
                )
            if owns_listener(self.server.pid):
                try:
                    if healthy():
                        return
                    last_failure = "OpenCode health connection refused."
                except TransientHealthError as error:
                    last_failure = str(error)
            remaining = deadline - time.monotonic()
            if remaining > 0:
                time.sleep(min(POLL_INTERVAL, remaining))
        raise RuntimeError(
            "OpenCode did not become ready at 127.0.0.1:4096; check global server configuration. "
            + last_failure + " " + STARTUP_GUIDANCE
        )

    def attach(self):
        self.check_signal()
        if self.server is not None:
            if self.server.poll() is not None or not owns_listener(self.server.pid):
                raise RuntimeError("Owned OpenCode listener disappeared before attachment.")
        # Inherit the terminal; /exit (not an in-TUI Ctrl+C) ends the client.
        print_browser_address()
        self.client = subprocess.Popen(["opencode", "attach", ENDPOINT, "--continue"])
        while self.client.poll() is None:
            self.check_signal()
            if self.server is not None and self.server.poll() is not None:
                raise RuntimeError("Owned OpenCode server exited while attached.")
            time.sleep(POLL_INTERVAL)
        self.check_signal()
        code = self.client.returncode
        return code if code >= 0 else 128 - code

    def run(self):
        handlers = {sig: signal.signal(sig, self.interrupted)
                    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)}
        descriptor = None
        try:
            lock = Path(tempfile.gettempdir()) / f"gentle-opencode-server-{os.getuid()}.lock"
            descriptor = os.open(lock, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
            info = os.fstat(descriptor)
            if info.st_uid != os.getuid() or not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077:
                raise RuntimeError("Unsafe OpenCode startup lock; refusing to proceed.")
            self.acquire_lock(descriptor)
            self.start()
            fcntl.flock(descriptor, fcntl.LOCK_UN)
            return self.attach()
        except InterruptedError:
            return 128 + self.signal
        finally:
            try:
                stop(self.client)
            finally:
                try:
                    stop(self.server)
                finally:
                    if descriptor is not None:
                        os.close(descriptor)
                    for sig, handler in handlers.items():
                        signal.signal(sig, handler)


if __name__ == "__main__":
    try:
        sys.exit(Session().run())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(f"[opencode-server] {error}", file=sys.stderr)
        sys.exit(1)
