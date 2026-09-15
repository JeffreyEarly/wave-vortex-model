"""Small independent guard checks; no MATLAB and no third-party packages."""

import argparse
import contextlib
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

import guardThermalReadiness as guard


SCRIPT = Path(guard.__file__)


class ValidationTests(unittest.TestCase):
    def test_limits_reject_nonfinite_and_nonpositive_values(self):
        for value in ("nan", "inf", "-inf", "0", "-1"):
            with self.subTest(value=value), self.assertRaises(argparse.ArgumentTypeError):
                guard.positive_finite(value)
        self.assertEqual(guard.positive_finite("16"), 16)

    def test_reused_descendant_pid_is_never_signalled(self):
        class Backend:
            def usage(self, _pid):
                value = guard.Usage()
                value.proc_start_abstime = 999
                return value

        family = guard.OwnedFamily(None, Backend())
        family.group_active = False
        family.births = {12345: 123}
        with patch.object(os, "kill") as kill:
            family.send(signal.SIGKILL)
        kill.assert_not_called()


@unittest.skipUnless(sys.platform == "darwin", "macOS libproc is required")
class MacGuardTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)

    def command(self, code, *, seconds=5, memory=1):
        return [sys.executable, str(SCRIPT), "--directory", str(self.folder / "run"),
                "--seconds", str(seconds), "--limit-gib", str(memory), "--",
                sys.executable, "-c", code]

    def result(self):
        return json.loads((self.folder / "run" / "result.json").read_text())

    def assert_stopped(self, pid):
        backend = guard.MacProcesses()
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            info = backend.usage(pid)
            if info is None or info.proc_exit_abstime:
                return
            time.sleep(.05)
        self.fail(f"Owned process {pid} still appears live after cleanup")

    def test_success_and_immutable_directory(self):
        command = self.command("print('finished',flush=True)")
        completed = subprocess.run(command, capture_output=True, text=True, timeout=8)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(self.result()["reason"], "completed")
        self.assertGreater(self.result()["osAccountedChildMaxResidentBytes"], 0)
        before = (self.folder / "run" / "result.json").read_bytes()
        repeated = subprocess.run(command, capture_output=True, timeout=8)
        self.assertNotEqual(repeated.returncode, 0)
        self.assertEqual((self.folder / "run" / "result.json").read_bytes(), before)

    def test_nonzero_command_is_not_success(self):
        completed = subprocess.run(self.command("raise SystemExit(7)"), capture_output=True, timeout=8)
        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(self.result()["reason"], "command-failed")
        self.assertEqual(self.result()["returncode"], 7)

    def test_descendant_memory_is_counted_and_unrelated_child_survives(self):
        sentinel = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(10)"], start_new_session=True)
        def stop_sentinel():
            if sentinel.poll() is None:
                sentinel.kill()
            sentinel.wait(timeout=3)
        self.addCleanup(stop_sentinel)
        child = "import time; data=bytearray(64*1024*1024); time.sleep(10)"
        code = f"import subprocess,sys; p=subprocess.Popen([sys.executable,'-c',{child!r}]); p.wait()"
        completed = subprocess.run(self.command(code, memory=.05), capture_output=True, text=True, timeout=8)
        self.assertNotEqual(completed.returncode, 0, completed.stderr)
        result = self.result()
        self.assertEqual(result["reason"], "memory-limit", result)
        self.assertGreaterEqual(len(result["observedPids"]), 2)
        self.assertGreaterEqual(result["peakSampledFootprintBytes"], .05*2**30)
        for pid in result["observedPids"]:
            self.assert_stopped(pid)
        self.assertIsNone(sentinel.poll(), "The unrelated child must not be signalled")
        sentinel.terminate()
        sentinel.wait(timeout=3)

    def test_launcher_exit_does_not_leave_term_ignoring_child(self):
        child = "import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(10)"
        code = f"import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',{child!r}]); time.sleep(.35)"
        completed = subprocess.run(self.command(code), capture_output=True, text=True, timeout=8)
        self.assertNotEqual(completed.returncode, 0, completed.stderr)
        result = self.result()
        self.assertEqual(result["reason"], "launcher-exited-with-descendants")
        for pid in result["observedPids"]:
            self.assert_stopped(pid)

    def test_wall_limit_cleans_observed_child_in_a_new_session(self):
        child = "import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(10)"
        code = f"import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',{child!r}],start_new_session=True); time.sleep(10)"
        completed = subprocess.run(self.command(code, seconds=.8), capture_output=True, text=True, timeout=8)
        self.assertNotEqual(completed.returncode, 0, completed.stderr)
        result = self.result()
        self.assertEqual(result["reason"], "wall-limit")
        self.assertGreaterEqual(len(result["observedPids"]), 2)
        for pid in result["observedPids"]:
            self.assert_stopped(pid)

    def test_cancellation_flushes_result_and_cleans_child(self):
        command = self.command("import time; time.sleep(10)")
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: process.poll() is None and process.kill())
        deadline = time.monotonic() + 3
        while not (self.folder / "run" / "contract.json").exists() and time.monotonic() < deadline:
            time.sleep(.02)
        process.send_signal(signal.SIGTERM)
        process.communicate(timeout=8)
        result = self.result()
        self.assertEqual(result["reason"], "cancelled", result)
        self.assertEqual(result["cancellationSignals"], [signal.SIGTERM])
        for pid in result["observedPids"]:
            self.assert_stopped(pid)

    def test_measurement_failure_fails_closed(self):
        class Unavailable(guard.MacProcesses):
            def usage(self, _pid):
                return None

        args = argparse.Namespace(directory=str(self.folder / "run"), limit_gib=1, seconds=5,
                                  command=[sys.executable, "-c", "import time; time.sleep(10)"])
        with contextlib.redirect_stdout(io.StringIO()):
            result = guard.run_command(args, Unavailable())
        self.assertEqual(result, 1)
        self.assertEqual(self.result()["reason"], "measurement-unavailable")
        contract = json.loads((self.folder / "run" / "contract.json").read_text())
        self.assert_stopped(contract["pid"])


if __name__ == "__main__":
    unittest.main()
