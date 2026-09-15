#!/usr/bin/env python3
"""Run one foreground authoring command with sampled macOS resource cutoffs.

The guard creates its own process group. It sums physical footprint over that
group and observed descendants, including observed children that change groups.
Only that group and birth-identity-checked descendants may receive signals.
Commands must not daemonize: polling cannot discover a child that both escapes
the group and is reparented between samples. SIGKILL of the guard, host shutdown,
and allocations between samples cannot be controlled by a userspace monitor.

Memory-limit termination is immediate. Wall limits and cancellation get a short
TERM grace followed by KILL, even when the launcher has already exited. Shared
pages may be counted more than once in the aggregate: this is a conservative
process-family cutoff, not a measurement of unique host memory or a reservation.
Run MATLAB outside the Codex sandbox, as required by the workspace policy.
"""

import argparse
import csv
import ctypes
import json
import math
import os
from pathlib import Path
import resource
import signal
import subprocess
import sys
import time
import traceback


class Usage(ctypes.Structure):
    """SDK sys/resource.h rusage_info_v0, selected by flavor zero."""

    _fields_ = [("uuid", ctypes.c_uint8 * 16)] + [
        (name, ctypes.c_uint64) for name in (
            "user_time", "system_time", "pkg_idle_wkups", "interrupt_wkups",
            "pageins", "wired_size", "resident_size", "phys_footprint",
            "proc_start_abstime", "proc_exit_abstime",
        )
    ]


class MacProcesses:
    def __init__(self):
        if sys.platform != "darwin":
            raise RuntimeError("The footprint guard requires macOS libproc.")
        self.library = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        self.library.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
        self.library.proc_pid_rusage.restype = ctypes.c_int
        for name in ("proc_listpgrppids", "proc_listchildpids"):
            function = getattr(self.library, name)
            function.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_int]
            function.restype = ctypes.c_int

    def usage(self, pid):
        info = Usage()
        if self.library.proc_pid_rusage(pid, 0, ctypes.byref(info)) != 0:
            return None
        return info

    def members(self, identifier, children=False):
        function = self.library.proc_listchildpids if children else self.library.proc_listpgrppids
        capacity = 64
        while capacity <= 65536:
            buffer = (ctypes.c_int * capacity)()
            count = function(identifier, buffer, ctypes.sizeof(buffer))
            if count < 0:
                raise OSError(ctypes.get_errno(), "libproc process enumeration failed")
            if count < capacity:
                return {pid for pid in buffer[:count] if pid > 0}
            capacity *= 2
        raise RuntimeError("The owned process family exceeds the enumeration bound.")


class OwnedFamily:
    def __init__(self, process, backend):
        self.process = process
        self.backend = backend
        self.births = {}
        self.group_active = True

    def sample(self):
        # Enumerate before reaping the launcher: its PID cannot be reused yet.
        members = self.backend.members(self.process.pid) if self.group_active else set()
        pending = list(members | set(self.births))
        seen = set()
        measured = {}
        missing = set()
        while pending:
            pid = pending.pop()
            if pid in seen:
                continue
            seen.add(pid)
            info = self.backend.usage(pid)
            if info is None:
                live = pid in members
                try:
                    os.getpgid(pid)
                    live = True
                except OSError:
                    pass
                if live:
                    missing.add(pid)
                continue
            birth = info.proc_start_abstime
            if not birth or (pid in self.births and self.births[pid] != birth):
                if pid in members:
                    missing.add(pid)
                continue
            self.births[pid] = birth
            if not info.proc_exit_abstime:
                measured[pid] = info
                pending.extend(self.backend.members(pid, children=True) - seen)
        returncode = self.process.poll()
        if returncode is not None and not members:
            self.group_active = False
        return measured, missing, returncode

    def send(self, signum):
        escaped = []
        # Resolve groups before signalling: the group signal can make later
        # getpgid calls race with a perfectly ordinary child exit.
        for pid, birth in self.births.items():
            info = self.backend.usage(pid)
            if info is None or info.proc_start_abstime != birth or info.proc_exit_abstime:
                continue
            try:
                if os.getpgid(pid) != self.process.pid:
                    escaped.append((pid, birth))
            except ProcessLookupError:
                pass
            except PermissionError:
                if self.backend.usage(pid) is not None:
                    raise
        if self.group_active:
            try:
                os.killpg(self.process.pid, signum)
            except ProcessLookupError:
                self.group_active = False
            except PermissionError:
                # The macOS sandbox can return EPERM for a vanished group.
                if self.process.poll() is None or self.backend.members(self.process.pid):
                    raise
                self.group_active = False
        for pid, birth in escaped:
            info = self.backend.usage(pid)
            if info is None or info.proc_start_abstime != birth or info.proc_exit_abstime:
                continue
            try:
                os.kill(pid, signum)
            except ProcessLookupError:
                pass

    def cleanup(self, immediate=False):
        self.send(signal.SIGKILL if immediate else signal.SIGTERM)
        deadline = time.monotonic() + (0 if immediate else .5)
        while time.monotonic() < deadline:
            measured, missing, _ = self.sample()
            if not measured and not missing:
                try:
                    return self.process.wait(timeout=.1)
                except subprocess.TimeoutExpired:
                    pass
            time.sleep(.05)
        # Recheck the group as well as descendants, even if launcher wait ended.
        if not immediate:
            self.send(signal.SIGKILL)
        try:
            return self.process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            return None


def positive_finite(text):
    value = float(text)
    if not math.isfinite(value) or value <= 0:
        raise argparse.ArgumentTypeError("Limits must be finite and strictly positive.")
    return value


def run_command(args, backend):
    output = Path(args.directory)
    output.mkdir(parents=True, exist_ok=False)
    start = time.monotonic()
    cancelled = []
    previous = {}
    for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        previous[signum] = signal.signal(signum, lambda received, _frame: cancelled.append(received))
    process = None
    family = None
    reason = "guard-error"
    detail = ""
    peak = resident_peak = samples = 0
    observed = set()
    returncode = None
    measurement_missing_since = None
    try:
        with (output / "output.log").open("w") as log, (output / "memory.csv").open("w") as stream:
            writer = csv.writer(stream)
            writer.writerow(["elapsedSeconds", "pids", "residentBytes", "physicalFootprintBytes", "unmeasuredPids"])
            stream.flush()
            process = subprocess.Popen(args.command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            family = OwnedFamily(process, backend)
            contract = dict(command=args.command, pid=process.pid, processGroup=process.pid,
                            limitGiB=args.limit_gib, maximumSeconds=args.seconds,
                            samplingIntervalSeconds=.25, termGraceSeconds=.5,
                            footprintAggregation="sum over owned group and observed descendants")
            (output / "contract.json").write_text(json.dumps(contract, indent=2))
            reason = "completed"
            while True:
                measured, missing, returncode = family.sample()
                elapsed = time.monotonic() - start
                observed.update(measured)
                footprint = sum(info.phys_footprint for info in measured.values())
                resident = sum(info.resident_size for info in measured.values())
                peak = max(peak, footprint)
                resident_peak = max(resident_peak, resident)
                samples += bool(measured)
                writer.writerow([elapsed, ";".join(map(str, sorted(measured))), resident, footprint,
                                 ";".join(map(str, sorted(missing)))])
                stream.flush()
                if missing or (returncode is None and not measured):
                    if measurement_missing_since is None:
                        measurement_missing_since = time.monotonic()
                else:
                    measurement_missing_since = None
                if cancelled:
                    reason = "cancelled"
                elif footprint >= args.limit_gib * 2**30:
                    reason = "memory-limit"
                elif elapsed >= args.seconds:
                    reason = "wall-limit"
                elif measurement_missing_since is not None and time.monotonic() - measurement_missing_since >= 1:
                    reason = "measurement-unavailable"
                elif returncode is not None:
                    if any(pid != process.pid for pid in measured) or missing:
                        reason = "launcher-exited-with-descendants"
                    elif returncode != 0:
                        reason = "command-failed"
                    break
                if reason != "completed":
                    break
                time.sleep(min(.25, max(0, args.seconds - elapsed)))
    except Exception as exception:
        reason = "guard-error"
        detail = f"{type(exception).__name__}: {exception}"
    finally:
        if family is not None:
            try:
                returncode = family.cleanup(immediate=reason == "memory-limit")
            except Exception as exception:
                # Group ownership comes from start_new_session, independent of
                # libproc availability; preserve cleanup if measurement fails.
                try:
                    if family.group_active:
                        os.killpg(process.pid, signal.SIGKILL)
                    returncode = process.wait(timeout=2)
                except (OSError, subprocess.TimeoutExpired):
                    pass
                reason = "cleanup-error"
                detail += traceback.format_exc()
        for signum, handler in previous.items():
            signal.signal(signum, handler)
        result = dict(reason=reason, returncode=returncode, elapsedSeconds=time.monotonic()-start,
                      peakSampledFootprintBytes=peak, peakSampledResidentBytes=resident_peak,
                      osAccountedChildMaxResidentBytes=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
                      osResidentAccounting="macOS ru_maxrss bytes for children reaped by this guard; not a simultaneous family-memory sum",
                      samples=samples, observedPids=sorted(observed), cancellationSignals=cancelled,
                      samplingIntervalSeconds=.25, detail=detail)
        (output / "result.json").write_text(json.dumps(result, indent=2))
        print(json.dumps(result), flush=True)
    return 0 if reason == "completed" and returncode == 0 else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", required=True)
    parser.add_argument("--limit-gib", type=positive_finite, default=8)
    parser.add_argument("--seconds", type=positive_finite, default=1800)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    if not args.command:
        parser.error("Supply a command after --.")
    if not math.isfinite(args.limit_gib * 2**30):
        parser.error("The memory limit is too large to represent in bytes.")
    return run_command(args, MacProcesses())


if __name__ == "__main__":
    sys.exit(main())
