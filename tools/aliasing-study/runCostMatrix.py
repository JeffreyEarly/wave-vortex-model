"""Run each frozen policy/case in a fresh MATLAB process with peak-RSS timing."""
import argparse
import json
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--output", default="cost-matrix-v1")
args = parser.parse_args()
if not re.fullmatch(r"[A-Za-z0-9_-]+", args.output):
    raise ValueError("Use a simple output-directory name.")
study = Path(__file__).resolve().parent
repo = study.parent.parent
inventory = json.loads((study / "case-inventory.json").read_text())
output = study / "results" / args.output
output.mkdir(exist_ok=True)
work = [(case["id"], policy) for case in inventory["calibration"] + inventory["withheld"] for policy in ["linear", "fixed", "targeted"]]
refinement = json.loads((study / "reference-refinements.json").read_text())
work += [(refinement["followup"]["id"], policy) for policy in ["linear", "fixed", "targeted"]]
work += [(inventory["larger"]["id"], policy) for policy in ["linear", "fixed", "targeted", "independent"]]
for case, policy in work:
    if not re.fullmatch(r"[A-Za-z0-9_-]+", case):
        raise ValueError("Unexpected case id.")
    name = f"{case}--{policy}"
    destination = output / name
    if (destination / "cost-summary.json").is_file():
        print(f"Preserving completed cost run {name}", flush=True)
        continue
    if destination.exists():
        raise SystemExit(f"Partial output {destination} requires investigation; its logs will not be overwritten.")
    expression = (
        "restoredefaultpath; addpath('tools/aliasing-study'); "
        "configureStudyPath('../wvm400-oceankit'); "
        f"runCostStudy('{case}','{policy}','tools/aliasing-study/results/{args.output}/{name}');"
    )
    print(f"Running {name}", flush=True)
    with (output / f"{name}.stdout.log").open("w") as stdout, (output / f"{name}.time.log").open("w") as stderr:
        result = subprocess.run(["/usr/bin/time", "-l", "matlab", "-batch", expression], cwd=repo, stdout=stdout, stderr=stderr, check=False)
    if result.returncode:
        raise SystemExit(f"Cost run {name} exited {result.returncode}; its outputs are preserved.")
    print(f"Completed {name}", flush=True)
