#!/usr/bin/env python3
"""Reject recorded outputs in the source tree; allow explicit source inputs."""
import argparse
import re
from pathlib import Path, PurePosixPath
import subprocess
import sys
from urllib.parse import unquote


OUTPUT_DIRS = {"results", "raw", "artifacts", "verification", "profile-results",
               "profiling-output", "test-results", "TestResults", "build",
               ".compiled-backend-cache", "__pycache__", ".pytest_cache"}
OUTPUT_SUFFIXES = {".csv", ".tsv", ".log", ".mat", ".nc", ".prof", ".profile",
                   ".gz", ".zip", ".tar", ".pdf", ".png", ".jpg", ".jpeg",
                   ".a", ".o", ".dylib", ".so", ".dll", ".pyc"}
SOURCE_INPUTS = {
    "resources/mpackage.json",
    "CompiledKernel/source-selection.json",
    "PortableRuntime/source-selection.json",
    "PortableRuntime/qualification/barotropic-qg-v1.json",
    "UnitTests/ReferenceImplementations/data/buoyancy-oracle.csv",
    "tools/scientific-validation-study/protocol.json",
    "tools/advection-form-study/comparison-protocol.json",
    "tools/thermodynamic-formulation-study/comparison-protocol.json",
}
JSON_INPUT_DIRS = ("PortableRuntime/contracts/", "PortableRuntime/examples/",
                   "PortableRuntime/tests/fixtures/", "Benchmarks/schemas/")


def artifact_reason(path):
    """Classify tracked paths, not generated contents or arbitrary extensions alone."""
    p = PurePosixPath(path)
    if any(part in OUTPUT_DIRS for part in p.parts[:-1]):
        return "recorded-output directory"
    if path.startswith(("docs/benchmarks/", "docs/assets/benchmarks/")):
        return "generated benchmark data or figure"
    if path in SOURCE_INPUTS:
        return None
    if p.suffix == ".json" and path.startswith(JSON_INPUT_DIRS):
        return None
    if p.suffix == ".nc" and path.startswith("PortableRuntime/tests/fixtures/"):
        return None
    if p.suffix.lower() in OUTPUT_SUFFIXES or p.suffix.lower().startswith(".mex"):
        return "recorded data, log, figure, or archive"
    if p.suffix == ".json":
        return "JSON without a declared source-input role"
    return None


def tracked_paths(root):
    output = subprocess.check_output(["git", "ls-files", "-z"], cwd=root)
    return [p for p in output.decode().split("\0") if p]


def violations(root, paths):
    # A staged or unstaged deletion is absent from the resulting source tree.
    return [(p, reason) for p in paths if (root / p).is_file()
            if (reason := artifact_reason(p))]


def removed_link_errors(root, paths, removed):
    """Check relative Markdown links to removed files; historical URLs stay valid."""
    deleted = {(root / p).resolve() for p in removed}
    found = []
    for path in paths:
        file = root / path
        if file.suffix != ".md" or not file.is_file():
            continue
        for target in re.findall(r"\]\(<?([^\s)>]+)>?\)", file.read_text()):
            if re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target) or target.startswith(("/", "#")):
                continue
            target = unquote(target.split("#", 1)[0])
            if (file.parent / target).resolve() in deleted:
                found.append((path, f"link to removed file: {target}"))
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--base", help="Git revision for checking references to deleted files")
    args = parser.parse_args()
    paths = tracked_paths(args.root)
    found = violations(args.root, paths)
    if args.base:
        removed = subprocess.check_output(["git", "diff", "--name-only", "--diff-filter=D", "-z", args.base, "--"], cwd=args.root).decode().split("\0")
        found.extend(removed_link_errors(args.root, paths, [p for p in removed if p]))
    for path, reason in found:
        print(f"{path}: {reason}", file=sys.stderr)
    if found:
        print("Keep recorded outputs outside the checkout; see AGENTS.md.", file=sys.stderr)
        return 1
    print("Repository artifact policy passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
