#!/usr/bin/env python3
"""Fail closed when a selected job fails, is cancelled, or is skipped."""

import json
import os


def check_gate(needs):
    if needs["changes"]["result"] != "success":
        raise ValueError("Repository policy and CI routing must succeed.")
    outputs = needs["changes"]["outputs"]
    for job, route in {
        "kernel-contract": "cpp", "portable-runtime-sanitizers": "cpp",
        "focused-matlab": "matlab", "documentation": "documentation", "package": "package",
    }.items():
        if outputs.get(route) not in {"true", "false"}:
            raise ValueError(f"Missing or invalid routing output: {route}")
        expected = "success" if outputs[route] == "true" else "skipped"
        actual = needs[job]["result"]
        if actual != expected:
            raise ValueError(f"{job}: expected {expected}, received {actual}")


if __name__ == "__main__":
    check_gate(json.loads(os.environ["WVM_CI_NEEDS"]))
    print("Repository policy and every selected CI check passed.")
