#!/usr/bin/env python3
"""No Docker, real OpenCode sessions, network listeners, or user configuration."""

import errno
from email.message import Message
import http.client
import importlib.util
import io
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
import urllib.error

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("supervisor", ROOT / ".taskfiles/scripts/opencode-server.py")
assert SPEC is not None and SPEC.loader is not None
supervisor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(supervisor)
REAL_HEALTHY = supervisor.healthy
PEER_MARKER = b"PRIVATE-PEER-TEXT"
BROKEN_HTTP = (
    (b"", http.client.RemoteDisconnected, True),
    (b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n40\r\n" + PEER_MARKER,
     http.client.IncompleteRead, True),
    (PEER_MARKER + b"\r\n", http.client.BadStatusLine, False),
)


def parsed_response(payload):
    """Exercise the standard HTTP parser without opening a network socket."""
    socket = Mock()
    socket.makefile.return_value = io.BytesIO(payload)
    response = http.client.HTTPResponse(socket)
    try:
        response.begin()
    except http.client.HTTPException:
        response.close()
        raise
    return response


def child(pid, code=None):
    process = Mock(pid=pid, returncode=code)
    process.poll.side_effect = lambda: process.returncode
    process.terminate.side_effect = lambda: setattr(process, "returncode", -signal.SIGTERM)
    process.kill.side_effect = lambda: setattr(process, "returncode", -signal.SIGKILL)
    return process


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir=ROOT)
        self.addCleanup(self.directory.cleanup)
        self.session = supervisor.Session()
        self.server = child(41000)
        self.client = child(41001, 0)
        self.clock = 0
        environment = patch.dict(os.environ, OPENCODE_PORT="12345")
        environment.start()
        self.addCleanup(environment.stop)
        self.output = self.replace("sys.stdout", new=io.StringIO())
        self.health = self.replace("healthy", return_value=False)
        self.owns = self.replace("owns_listener", return_value=True)
        self.spawn = self.replace("subprocess.Popen", side_effect=[self.server, self.client])
        self.replace("tempfile.gettempdir", return_value=self.directory.name)
        self.replace("time.sleep", side_effect=self.advance)
        self.replace("time.monotonic", side_effect=lambda: self.clock)

    def replace(self, name, **kwargs):
        owner = supervisor
        if "." in name:
            namespace, name = name.split(".")
            owner = getattr(supervisor, namespace)
        context = patch.object(owner, name, **kwargs)
        result = context.start()
        self.addCleanup(context.stop)
        return result

    def advance(self, seconds):
        self.clock += seconds

    def ready(self):
        self.health.side_effect = [False, True]

    def test_client_completion_or_spawn_failure_cleans_only_owned_server(self):
        for reused in (False, True):
            for outcome in (0, 7, OSError("cannot attach")):
                with self.subTest(reused=reused, outcome=outcome):
                    self.session = supervisor.Session()
                    self.server = child(41000)
                    self.client = child(41001, outcome)
                    self.health.side_effect = [True] if reused else [False, True]
                    self.spawn.reset_mock(side_effect=True)
                    attach = outcome if isinstance(outcome, OSError) else self.client
                    self.spawn.side_effect = [attach] if reused else [self.server, attach]
                    if isinstance(outcome, OSError):
                        with self.assertRaises(OSError):
                            self.session.run()
                    else:
                        self.assertEqual(self.session.run(), outcome)
                    self.assertEqual(self.spawn.call_args.args[0],
                                     ["opencode", "attach", "http://127.0.0.1:4096", "--continue"])
                    self.assertEqual(self.spawn.call_args.kwargs, {})
                    self.assertEqual(self.spawn.call_count, 1 if reused else 2)
                    if reused:
                        self.server.terminate.assert_not_called()
                    else:
                        serve = self.spawn.call_args_list[0]
                        self.assertEqual(serve.args[0], ["opencode", "serve"])
                        self.assertTrue(serve.kwargs["start_new_session"])
                        self.server.terminate.assert_called_once()

    def test_start_failure_reports_status_and_safe_manual_diagnostics(self):
        for code, reason in ((42, "exit code 42"), (-15, "signal 15"), (0, "exit code 0")):
            with self.subTest(code=code):
                self.session = supervisor.Session()
                self.server = child(41000, code)
                self.spawn.reset_mock(side_effect=True)
                self.spawn.side_effect = [self.server]
                with patch.dict(os.environ, OPENCODE_SERVER_PASSWORD="private-test-password"):
                    with self.assertRaises(RuntimeError) as failure:
                        self.session.run()
                message = str(failure.exception)
                self.assertIn(reason, message)
                self.assertIn("`opencode serve`", message)
                self.assertIn("same container and workspace", message)
                self.assertNotIn("private-test-password", message)
                self.assertEqual(self.spawn.call_args.kwargs["stdout"], subprocess.DEVNULL)
                self.assertEqual(self.spawn.call_args.kwargs["stderr"], subprocess.DEVNULL)
                self.assertEqual(self.spawn.call_count, 1)

    def test_owned_transient_failure_then_success(self):
        self.health.side_effect = [False, supervisor.TransientHealthError("timed out"), False, True]
        self.assertEqual(self.session.run(), 0)
        self.assertEqual(self.health.call_count, 4)
        self.server.terminate.assert_called_once()

    def test_readiness_exhaustion_is_bounded_and_cleans_without_attach(self):
        for transient in (False, True):
            with self.subTest(transient=transient):
                self.session = supervisor.Session()
                self.server = child(41000)
                self.clock = 0
                self.spawn.reset_mock(side_effect=True)
                self.spawn.side_effect = [self.server]

                def check():
                    if transient and self.session.server is not None:
                        self.advance(2)
                        raise supervisor.TransientHealthError("timed out")
                    return False

                self.health.side_effect = check
                with self.assertRaisesRegex(RuntimeError, "did not become ready") as failure:
                    self.session.run()
                self.assertIn("`opencode serve`", str(failure.exception))
                self.assertLessEqual(self.clock, supervisor.START_TIMEOUT + 2)
                self.server.terminate.assert_called_once()
                self.assertEqual(self.spawn.call_count, 1)

    def test_initial_http_parser_failures_never_authorize_replacement(self):
        for payload, exception, transient in BROKEN_HTTP:
            with self.subTest(exception=exception.__name__):
                self.session = supervisor.Session()
                self.health.side_effect = REAL_HEALTHY
                with self.assertRaises(exception):
                    with parsed_response(payload) as response:
                        response.read(65536)
                with patch.object(supervisor.urllib.request, "build_opener") as opener:
                    opener.return_value.open.side_effect = lambda *a, **kw: parsed_response(payload)
                    with self.assertRaises(RuntimeError) as failure:
                        self.session.run()
                    self.assertEqual(opener.return_value.open.call_count, 1)
                self.assertNotIn(PEER_MARKER.decode(), str(failure.exception))
                self.assertEqual(isinstance(failure.exception, supervisor.TransientHealthError), transient)
                self.assertTrue(failure.exception.__suppress_context__)
                self.spawn.assert_not_called()

    def test_uncertain_or_unrelated_endpoint_never_authorizes_replacement(self):
        errors = [TimeoutError("private"),
                  urllib.error.URLError(TimeoutError("private")),
                  urllib.error.URLError(urllib.error.URLError(TimeoutError("private"))),
                  ConnectionResetError(errno.ECONNRESET, "private"),
                  OSError(errno.EACCES, "private")]
        errors += [urllib.error.HTTPError(supervisor.ENDPOINT, status, "private", Message(), io.BytesIO())
                   for status in (301, 401, 403, 503)]
        bodies = [b"private invalid JSON", b'{"healthy":true}',
                  b'{"healthy":"true","version":"x"}', b"{}", b"[]"]
        for failure in errors + bodies:
            with self.subTest(failure=failure):
                self.session = supervisor.Session()
                self.health.side_effect = REAL_HEALTHY
                with patch.object(supervisor.urllib.request, "build_opener") as opener:
                    if isinstance(failure, bytes):
                        opener.return_value.open.side_effect = lambda *a, **kw: parsed_response(
                            b"HTTP/1.1 200 OK\r\n\r\n" + failure)
                    else:
                        opener.return_value.open.side_effect = failure
                    with self.assertRaises(RuntimeError) as rejected:
                        self.session.run()
                    self.assertEqual(opener.return_value.open.call_count, 1)
                self.assertNotIn("private", str(rejected.exception))
                transient = isinstance(failure, (TimeoutError, ConnectionResetError, urllib.error.URLError))
                if isinstance(failure, urllib.error.HTTPError):
                    transient = False
                self.assertEqual(isinstance(rejected.exception, supervisor.TransientHealthError), transient)
                self.spawn.assert_not_called()

    def test_owned_http_parser_failures_retry_only_transient(self):
        valid = b'HTTP/1.1 200 OK\r\n\r\n{"healthy":true,"version":"test"}'
        for payload, exception, transient in BROKEN_HTTP:
            with self.subTest(exception=exception.__name__):
                self.session = supervisor.Session()
                self.server = child(41000)
                self.spawn.reset_mock(side_effect=True)
                self.spawn.side_effect = [self.server, self.client]
                self.health.side_effect = REAL_HEALTHY
                attempts = iter([None, payload, valid])

                def open_response(*args, **kwargs):
                    body = next(attempts)
                    if body is None:
                        raise ConnectionRefusedError(errno.ECONNREFUSED, "refused")
                    return parsed_response(body)

                with patch.object(supervisor.urllib.request, "build_opener") as opener:
                    opener.return_value.open.side_effect = open_response
                    if transient:
                        self.assertEqual(self.session.run(), 0)
                    else:
                        with self.assertRaisesRegex(RuntimeError, "invalid HTTP") as failure:
                            self.session.run()
                        self.assertNotIn(PEER_MARKER.decode(), str(failure.exception))
                    self.assertEqual(opener.return_value.open.call_count, 3 if transient else 2)
                self.assertEqual(self.spawn.call_count, 2 if transient else 1)
                self.server.terminate.assert_called_once()

    def test_owned_permanent_failure_is_not_retried(self):
        for message in ("invalid JSON", "invalid schema", "authentication", "HTTP 503"):
            with self.subTest(message=message):
                self.session = supervisor.Session()
                self.server = child(41000)
                self.spawn.reset_mock(side_effect=True)
                self.spawn.side_effect = [self.server]
                self.health.reset_mock(side_effect=True)
                self.health.side_effect = [False, RuntimeError(message)]
                with self.assertRaisesRegex(RuntimeError, message):
                    self.session.run()
                self.assertEqual(self.health.call_count, 2)
                self.assertEqual(self.spawn.call_count, 1)
                self.server.terminate.assert_called_once()

    def test_browser_address_emitted_once_before_attach_for_start_and_reuse(self):
        for reused, port in ((False, "1"), (True, "65535"), (False, "01234"), (True, "12345")):
            with self.subTest(reused=reused, port=port), patch.dict(os.environ, OPENCODE_PORT=port):
                self.session = supervisor.Session()
                self.server = child(41000)
                self.health.side_effect = [True] if reused else [False, True]
                self.output.seek(0)
                self.output.truncate()

                def spawn(command, **kwargs):
                    if command[1] == "serve":
                        self.assertEqual(self.output.getvalue(), "")
                        return self.server
                    self.assertEqual(self.output.getvalue().count(f"http://localhost:{int(port)}/"), 1)
                    self.assertNotIn("localhost:4096", self.output.getvalue())
                    return self.client

                self.spawn.side_effect = spawn
                self.assertEqual(self.session.run(), 0)

    def test_invalid_browser_port_warns_without_blocking_attach(self):
        for port in (None, "", "0", "65536", "-1", " 1234", "１２３４", "1\nINJECT", "$(id)", "9" * 5000):
            with self.subTest(port=port and port[:20]):
                self.session = supervisor.Session()
                self.health.return_value = True
                self.spawn.side_effect = [self.client]
                with patch.dict(os.environ, {}, clear=True):
                    if port is not None:
                        os.environ["OPENCODE_PORT"] = port
                    with patch.object(sys, "stderr", new=io.StringIO()) as warning:
                        self.assertEqual(self.session.run(), 0)
                self.assertIn("missing or invalid", warning.getvalue())
                self.assertLess(len(warning.getvalue()), 180)
                self.assertNotIn("http://", self.output.getvalue())

    def test_wrong_port_or_racing_listener_is_not_attached(self):
        self.owns.return_value = False
        self.health.side_effect = [False, True]
        with self.assertRaisesRegex(RuntimeError, "did not become ready"):
            self.session.run()
        self.assertEqual(self.health.call_count, 1)
        self.assertEqual(self.spawn.call_count, 1)
        self.server.terminate.assert_called_once()

    def test_listener_lost_between_readiness_and_attach(self):
        self.ready()
        self.owns.side_effect = [True, False]
        with self.assertRaisesRegex(RuntimeError, "disappeared"):
            self.session.run()
        self.assertEqual(self.spawn.call_count, 1)

    def test_owned_server_death_ends_client(self):
        self.ready()
        self.client.returncode = None
        self.server.poll.side_effect = [None, None, 1, 1]
        with self.assertRaisesRegex(RuntimeError, "exited while attached"):
            self.session.run()
        self.client.terminate.assert_called_once()

    def test_wrapper_signals_stop_owned_processes(self):
        for reused, sig in ((False, signal.SIGTERM), (False, signal.SIGHUP),
                            (False, signal.SIGINT), (True, signal.SIGTERM)):
            with self.subTest(reused=reused, signal=sig):
                self.session = supervisor.Session()
                self.server = child(41000)
                self.client = child(41001)
                self.health.side_effect = [True] if reused else [False, True]
                self.spawn.side_effect = [self.client] if reused else [self.server, self.client]

                def interrupt(seconds):
                    signal.raise_signal(sig)

                with patch.object(supervisor.time, "sleep", side_effect=interrupt):
                    self.assertEqual(self.session.run(), 128 + sig)
                self.assertEqual(self.server.terminate.call_count, 0 if reused else 1)
                self.client.terminate.assert_called_once()

    def test_signal_during_spawn_records_ownership_before_cleanup(self):
        def spawn(*args, **kwargs):
            signal.raise_signal(signal.SIGTERM)
            return self.server

        self.spawn.side_effect = spawn
        self.assertEqual(self.session.run(), 143)
        self.server.terminate.assert_called_once()

    def test_startup_lock_timeout_never_spawns(self):
        with patch.object(supervisor.fcntl, "flock", side_effect=BlockingIOError):
            with self.assertRaisesRegex(RuntimeError, "waiting for another"):
                self.session.run()
        self.assertLess(self.clock, supervisor.LOCK_TIMEOUT + 1)
        self.spawn.assert_not_called()

    def test_waiting_invocation_reuses_server_after_real_lock_release(self):
        lock = Path(self.directory.name) / f"gentle-opencode-server-{os.getuid()}.lock"
        descriptor = os.open(lock, os.O_CREAT | os.O_RDWR, 0o600)
        self.addCleanup(os.close, descriptor)
        supervisor.fcntl.flock(descriptor, supervisor.fcntl.LOCK_EX)
        self.health.return_value = True
        self.spawn.side_effect = [self.client]

        def release(seconds):
            supervisor.fcntl.flock(descriptor, supervisor.fcntl.LOCK_UN)
            self.advance(seconds)

        with patch.object(supervisor.time, "sleep", side_effect=release) as sleep:
            self.assertEqual(self.session.run(), 0)
        sleep.assert_called_once()
        self.assertEqual(self.spawn.call_count, 1)
        self.server.terminate.assert_not_called()

    def test_symlink_lock_is_rejected(self):
        lock = Path(self.directory.name) / f"gentle-opencode-server-{os.getuid()}.lock"
        lock.symlink_to(Path(self.directory.name) / "unrelated")
        with self.assertRaises(OSError):
            self.session.run()
        self.spawn.assert_not_called()


class Protocol(unittest.TestCase):
    def test_other_and_nested_http_exceptions_are_sanitized(self):
        for error, transient in (
            (http.client.HTTPException(PEER_MARKER.decode()), False),
            (http.client.LineTooLong(PEER_MARKER.decode()), False),
            (urllib.error.URLError(http.client.BadStatusLine(PEER_MARKER.decode())), False),
            (urllib.error.URLError(http.client.RemoteDisconnected(PEER_MARKER.decode())), True),
            (urllib.error.URLError(http.client.IncompleteRead(PEER_MARKER)), True),
        ):
            with self.subTest(error=type(error).__name__):
                with patch.object(supervisor.urllib.request, "build_opener") as opener:
                    opener.return_value.open.side_effect = error
                    with self.assertRaisesRegex(RuntimeError, "HTTP") as failure:
                        supervisor.healthy()
                self.assertEqual(isinstance(failure.exception, supervisor.TransientHealthError), transient)
                self.assertNotIn(PEER_MARKER.decode(), str(failure.exception))

    def test_response_read_timeout_is_transient(self):
        response = Mock(status=200)
        response.read.side_effect = TimeoutError("private")
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=False)
        with patch.object(supervisor.urllib.request, "build_opener") as opener:
            opener.return_value.open.return_value = response
            with self.assertRaisesRegex(supervisor.TransientHealthError, "timed out"):
                supervisor.healthy()

    def test_raw_and_nested_refusal_are_absence(self):
        error = ConnectionRefusedError(errno.ECONNREFUSED, "refused")
        for wrapped in (error, urllib.error.URLError(urllib.error.URLError(error))):
            with patch.object(supervisor.urllib.request, "build_opener") as opener:
                opener.return_value.open.side_effect = wrapped
                self.assertFalse(supervisor.healthy())

    def test_shell_launcher_resolves_helper_from_another_directory(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as directory:
            executable = Path(directory) / "python3"
            executable.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            executable.chmod(0o755)
            environment = dict(os.environ, PATH=directory + os.pathsep + os.defpath)
            result = subprocess.run(
                ["/bin/bash", str(ROOT / ".taskfiles/scripts/opencode-server.sh")],
                cwd=directory, env=environment, capture_output=True, text=True, timeout=5,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), str(ROOT / ".taskfiles/scripts/opencode-server.py"))

    def test_health_alarm_bounds_slow_response_and_restores_handler(self):
        previous = signal.getsignal(signal.SIGALRM)
        with self.assertRaises(TimeoutError):
            with supervisor.health_deadline():
                signal.raise_signal(signal.SIGALRM)
        self.assertEqual(signal.getsignal(signal.SIGALRM), previous)
        self.assertEqual(signal.getitimer(signal.ITIMER_REAL), (0.0, 0.0))

    def test_auth_is_a_header_not_a_command_argument(self):
        with patch.dict(os.environ, OPENCODE_SERVER_PASSWORD="secret", OPENCODE_SERVER_USERNAME="user"):
            with patch.object(supervisor.urllib.request, "build_opener") as opener:
                opener.return_value.open.side_effect = urllib.error.URLError(ConnectionRefusedError(errno.ECONNREFUSED, "refused"))
                self.assertFalse(supervisor.healthy())
                request = opener.return_value.open.call_args.args[0]
                self.assertEqual(request.get_header("Authorization"), "Basic dXNlcjpzZWNyZXQ=")
                handlers = opener.call_args.args
                self.assertEqual(handlers[0].proxies, {})
                self.assertIsNone(handlers[1].redirect_request(None, None, 302, None, None, "http://other"))

    def test_listener_requires_child_socket_not_just_port(self):
        descriptor = Mock()
        descriptor.readlink.return_value = Path("socket:[123]")
        table = "header\n0: 00000000:1000 00000000:0000 0A 0 0 0 0 0 123\n"
        with patch.object(Path, "iterdir", return_value=[descriptor]):
            with patch.object(Path, "read_text", return_value=table):
                self.assertTrue(supervisor.owns_listener(41000))
                descriptor.readlink.return_value = Path("socket:[999]")
                self.assertFalse(supervisor.owns_listener(41000))

    def test_cleanup_escalates_only_owned_child(self):
        process = child(41000)
        process.wait.side_effect = [subprocess.TimeoutExpired("opencode", 3), 0]
        supervisor.stop(process)
        process.terminate.assert_called_once()
        process.kill.assert_called_once()
        self.assertEqual(process.wait.call_count, 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
