#!/usr/bin/env python3
"""Bind unchanged C++ measurements to an integrated commit without relabeling execution."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main(commit):
    folder = Path(__file__).resolve().parent
    root = folder.parents[2]
    original = folder / "qualification.json"
    original_sha = sha(original)
    receipt = json.loads(original.read_text())
    for item in receipt["artifacts"]:
        assert sha(folder / item["path"]) == item["sha256"], item["path"]
    for item in (receipt["sourceConsumer"], receipt["processMemory"]):
        assert sha(folder / item["path"]) == item["sha256"], item["path"]
    for item in receipt["nativeLifecycles"]:
        assert sha(folder / item["report"]) == item["sha256"], item["report"]
    source = receipt["productionSource"]
    names = subprocess.check_output(["git", "-C", str(root), "ls-tree", "-r", "--name-only",
                                     commit, "--", *source["prefixes"]], text=True).splitlines()
    names = {path for path in names if Path(path).suffix in (".cpp", ".hpp", ".h", ".c")
             or Path(path).name == "CMakeLists.txt"}
    assert names == {item["path"] for item in source["files"]}, "C++ source inventory changed"
    for item in source["files"]:
        assert sha(root / item["path"]) == item["sha256"], item["path"]
        committed = subprocess.check_output(["git", "-C", str(root), "show", commit + ":" + item["path"]])
        assert hashlib.sha256(committed).hexdigest() == item["sha256"], item["path"]
    supplement = ".github/ci-evidence/issue-391-density-output/ci-repair/endpoint-repair.json"
    matlab_source = "Operations/@WVNoMotionProfile/WVNoMotionProfile.m"
    correction = json.loads((root / supplement).read_text())
    for item in correction["artifacts"]:
        assert sha((root / supplement).parent / item["path"]) == item["sha256"], item["path"]
    results = json.loads(((root / supplement).parent / "inverse-results.json").read_text())
    assert len(results) == 13 and all(row["passed"] and not row["failed"] and not row["incomplete"] for row in results)
    binding = {
        "schema": "wave-vortex-local-qualification-integration-binding-v1",
        "issue": 307,
        "integratedCommit": commit,
        "verifiedAtUTC": datetime.now(timezone.utc).isoformat(),
        "originalReceipt": {"path": "qualification.json", "sha256": original_sha,
                            "executionCommit": receipt["sourceCommit"],
                            "assemblyCommit": receipt["assemblyCommit"]},
        "verifiedOriginalArtifactCount": len(receipt["artifacts"]),
        "nestedSourceConsumerProcessMemoryAndLifecycleHashesVerified": True,
        "cppProductionFileCount": len(source["files"]),
        "cppProductionSHA256": source["sha256"],
        "cppProductionMatchesOriginalExecution": True,
        "workingTreeCppProductionMatchesIntegratedCommit": True,
        "classification": "Inherited execution bound to byte-identical integrated C++ sources; not a new measurement campaign.",
        "matlabCorrection": {
            "issue": 456, "path": matlab_source, "sha256": sha(root / matlab_source),
            "scope": "MATLAB inverse publication corrects only rounding-sized endpoint excursions within its existing height tolerance; strict input rejection and interior results are preserved.",
            "qualificationSupplement": supplement, "qualificationSupplementSHA256": sha(root / supplement),
            "verifiedSupplementArtifactCount": len(correction["artifacts"]),
            "verifiedPassingFocusedMethods": len(results),
            "note": "MATLAB scientific source changed, so this receipt makes no blanket MATLAB-source-equivalence claim. The separately retained red/green regression and 32-cell ordinary/dense rerun qualify the correction."
        },
        "decision": "partial-local-gates-only", "standardPortableParity": False,
        "remainingDecisionInputs": ["assembled compatibility matrix completeness", "final required hosted qualification results"]
    }
    output = folder / ("integration-binding-" + commit[:8] + ".json")
    output.write_text(json.dumps(binding, indent=2) + "\n")
    assert sha(original) == original_sha, "Original execution receipt was modified"
    print(f"Verified {len(receipt['artifacts'])} original artifact hashes and {len(source['files'])} unchanged C++ source files; wrote {output.name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--commit", required=True)
    main(parser.parse_args().commit)
