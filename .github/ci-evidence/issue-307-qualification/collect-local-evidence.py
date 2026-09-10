#!/usr/bin/env python3
"""Collect source-bound receipts after the commands in reproduce-local.sh."""
import hashlib
import argparse
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
ATS = ROOT.parent / "AlongTrackSimulator"
BUILD = Path("/private/tmp/wvm307-ats-build")
NATIVE = Path("/private/tmp/wvm-v4-audit-runtime")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def identity(root, prefixes):
    paths = git(root, "ls-files", "--", *prefixes).splitlines()
    rows = [{"path": path, "sha256": sha(root / path)} for path in paths
            if Path(path).suffix in (".cpp", ".hpp", ".h", ".c") or Path(path).name == "CMakeLists.txt"]
    rows.sort(key=lambda row: row["path"])
    content = "".join(f"{row['sha256']}  {row['path']}\n" for row in rows).encode()
    return {"algorithm": "SHA256 of sorted UTF-8 <sha256><two spaces><relative path><LF> lines",
            "prefixes": prefixes, "sha256": hashlib.sha256(content).hexdigest(), "files": rows}


def main(execution_commit):
    production = identity(ROOT, ["CompiledKernel", "PortableRuntime/include", "PortableRuntime/src",
                                 "PortableRuntime/app", "PortableRuntime/third_party"])
    measured_commit = "8d6248c0273d603e29e6e5ca904a40cf339a5261"
    measured_paths = git(ROOT, "ls-tree", "-r", "--name-only", measured_commit, "--", *production["prefixes"]).splitlines()
    measured_paths = {path for path in measured_paths if Path(path).suffix in (".cpp", ".hpp", ".h", ".c")
                      or Path(path).name == "CMakeLists.txt"}
    if measured_paths != {row["path"] for row in production["files"]}:
        raise RuntimeError("Measured #447 production file inventory changed")
    changed_production = [row["path"] for row in production["files"]
                          if hashlib.sha256(subprocess.check_output(
                              ["git", "-C", str(ROOT), "show", measured_commit + ":" + row["path"]])).hexdigest() != row["sha256"]]
    if changed_production:
        raise RuntimeError("Measured #447 source reuse needs review: production tree changed")
    if git(ATS, "status", "--porcelain"):
        raise RuntimeError("ATS worktree is no longer clean")
    tests = ET.parse(OUT / "ats/tests.xml").getroot()
    cases = tests.findall("testcase")
    if len(cases) != 7 or any(case.find("failure") is not None or case.find("skipped") is not None for case in cases):
        raise RuntimeError("Expected all seven current source-consumer tests to pass")
    executables = ["alongtrack_portable_core_tests",
                   "cpp/extensions/wavevortex/alongtrack-wave-vortex-run",
                   "cpp/extensions/wavevortex/alongtrack_wavevortex_extension_routing_tests",
                   "cpp/extensions/wavevortex/alongtrack_wavevortex_extension_tests",
                   "cpp/extensions/wavevortex/alongtrack_wavevortex_runner_end_to_end_tests",
                   "wavevortex-portable-runtime/wave-vortex-run"]
    ats = {"schema": "wave-vortex-source-consumer-qualification-v1", "issue": 307,
           "status": "passed", "waveVortexQualifiedCommit": execution_commit,
           "assemblyCommit": git(ROOT, "rev-parse", "HEAD"),
           "waveVortexProductionSource": production,
           "consumerRepository": "satmapkit/AlongTrackSimulator",
           "consumerCommit": git(ATS, "rev-parse", "HEAD"), "consumerWorktreeClean": True,
           "consumerSource": identity(ATS, ["cpp", "CMakeLists.txt"]),
           "platform": "Apple Silicon macOS; AppleClang Release; reference FFT; warnings as errors",
           "testCount": len(cases), "testFailures": 0,
           "tests": [{"name": case.attrib["name"], "seconds": float(case.attrib["time"])} for case in cases],
           "cmakeCacheSHA256": sha(BUILD / "CMakeCache.txt"),
           "executables": [{"path": path, "sha256": sha(BUILD / path)} for path in executables],
           "scope": "Fresh local source-linked consumer execution; no consumer source changes. Cross-platform and package-export proof are separate gates."}
    (OUT / "ats/qualification.json").write_text(json.dumps(ats, indent=2) + "\n")
    cycles = []
    for family, target in (("hydrostatic", "WVHydrostaticLifecycleProbe"),
                           ("boussinesq", "WVBoussinesqLifecycleProbe")):
        path = OUT / f"lifecycle/{family}.json"
        row = json.loads(path.read_text())
        assert row["completedLifecycles"] == 6 and row["scientificOwnersReleased"]
        assert row["retainedGrowthBytes"] == 0 and row["preparedStepAllocations"] == 0
        assert row["finalStateFinite"]
        cycles.append({"family": family, "report": str(path.relative_to(OUT)), "sha256": sha(path),
                       "executable": str(NATIVE / target), "executableSHA256": sha(NATIVE / target),
                       "fixtureSHA256": sha(Path("/private/tmp/wvm305-performance") / f"{family}-source.nc"),
                       "grid": row["grid"], "completedLifecycles": 6, "passes": True,
                       "testSources": [{"path": path, "sha256": sha(ROOT / path)} for path in
                                       ("PortableRuntime/tests/WVStratifiedLifecycleProbe.cpp",
                                        "tools/compiled-kernel/tests/WVAllocationProbe.cpp",
                                        "tools/compiled-kernel/tests/WVAllocationProbe.hpp")]})
    reuse_paths = ["PortableRuntime/qualification/forward-integration-reference-v1.json",
                   "PortableRuntime/qualification/forward-integration-native-fftw-v1.json",
                   ".github/ci-evidence/issue-391-density-output/public-output/verification.json",
                   ".github/ci-evidence/issue-391-density-output/performance/verification.json"]
    receipt = {"schema": "wave-vortex-current-local-qualification-v1", "issue": 307,
               "sourceCommit": execution_commit,
               "assemblyCommit": git(ROOT, "rev-parse", "HEAD"),
               "workingTreeChanges": git(ROOT, "status", "--porcelain").splitlines(),
               "productionSource": production,
               "currentProductionEqualsMeasured447Commit": "8d6248c0273d603e29e6e5ca904a40cf339a5261",
               "sourceSelectionMetadataCorrection": {"path": "CompiledKernel/source-selection.json",
                    "currentSHA256": sha(ROOT / "CompiledKernel/source-selection.json"),
                    "note": "Post-execution repair updates its keySourceSHA256.kernel authority digest only. The enumerated C++/header/CMake production files are compared byte-for-byte separately; this metadata repair is not a new numerical execution."},
               "scientificEvidenceReuse": [{"path": path, "sha256": sha(ROOT / path),
                                            "classification": "inherited execution; exact production-source match, not a fresh run"}
                                           for path in reuse_paths],
               "sourceConsumer": {"path": "ats/qualification.json", "sha256": sha(OUT / "ats/qualification.json"), "passes": True},
               "nativeLifecycles": cycles,
               "sourceExport": {"classification": "separate required hosted gate; no local export claim"},
               "decision": "partial-local-gates-only",
               "standardPortableParity": False,
               "remainingDecisionInputs": ["assembled matrix completeness", "current required platform and package-export gates", "prospective process-memory results"]}
    memory = OUT / "process-memory/qualification.json"
    if memory.exists():
        memory_value = json.loads(memory.read_text())
        receipt["processMemory"] = {"path": str(memory.relative_to(OUT)), "sha256": sha(memory),
                                    "passes": memory_value.get("passes", False)}
        receipt["remainingDecisionInputs"].remove("prospective process-memory results")
    receipt["artifacts"] = [{"path": str(path.relative_to(OUT)), "sha256": sha(path)}
                            for path in sorted(OUT.rglob("*")) if path.is_file()
                            and path.name != "qualification.json" and "__pycache__" not in path.parts]
    (OUT / "qualification.json").write_text(json.dumps(receipt, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execution-source-commit", required=True)
    main(parser.parse_args().execution_source_commit)
