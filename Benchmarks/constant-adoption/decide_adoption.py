#!/usr/bin/env python3
"""Apply the prospectively declared #358 gates to complete final campaigns."""
import argparse
import json
from pathlib import Path


def read(folder, name):
    return json.loads((folder / name).read_text())


def decide(native, matlab, model, selection):
    checks = []
    campaigns = []

    def require(name, passed, actual=None, bound=None):
        checks.append({"gate": name, "passed": bool(passed), "actual": actual, "bound": bound})

    for boundary, folder in [("native", native), ("matlab-loaded", matlab)]:
        manifest, runs, summary = [read(folder, name) for name in ("manifest.json", "runs.json", "summary.json")]
        campaigns.append(manifest)
        require(boundary + ": correct execution boundary", manifest["interface"] == boundary)
        require(boundary + ": final protocol", manifest["mode"] == "final" and manifest["pairs"] == 8 and manifest["warmups"] == 2 and manifest["samples"] == 7)
        require(boundary + ": all paired profiles", len(runs) == 64 and len(summary["profiles"]) == 4 and all(row["pairs"] == 8 for row in summary["profiles"]))
        require(boundary + ": independent MATLAB agreement", all(r["exitCode"] == 0 and r["matlabComparison"]["passed"] for r in runs))
        candidates = [r for r in runs if r["role"] == "candidate"]
        require(boundary + ": frozen control agreement", len(candidates) == 32 and all(r["controlComparison"]["passed"] for r in candidates))
        require(boundary + ": geometric flux improvement", summary["geometricFluxRatio"] <= .90, summary["geometricFluxRatio"], .90)
        require(boundary + ": no profile regression", all(r["fluxRatio"] <= 1.03 for r in summary["profiles"]), {r["profile"]: r["fluxRatio"] for r in summary["profiles"]}, 1.03)
        require(boundary + ": paired interval excludes tie", summary["fluxPairedBootstrap95"][1] < 1, summary["fluxPairedBootstrap95"], 1)
        require(boundary + ": complete-lifetime RSS", summary["geometricPeakRSSRatio"] <= 1 and summary["peakRSSPairedBootstrap95"][1] <= 1.03, [summary["geometricPeakRSSRatio"], summary["peakRSSPairedBootstrap95"]], [1, 1.03])
        controls = {(r["profile"], r["pair"]): r for r in runs if r["role"] == "control"}
        ratios = []
        for candidate in candidates:
            control = controls[candidate["profile"], candidate["pair"]]
            def owned(run):
                worker = run["worker"]
                return worker["adoption"]["kernelPersistentBytes"] if boundary == "native" else worker["metrics"]["persistentBytes"]
            ratios.append(owned(candidate) / owned(control))
        require(boundary + ": no owned-memory growth", all(r <= 1 for r in ratios), max(ratios), 1)
        policy = manifest["provenance"]["effectivePolicy"]
        require(boundary + ": selected shared policy", policy["pointwiseWorkers"] == selection["selectedPointwiseWorkers"] and policy["candidateHorizontalOuter"] == 12 and policy["candidateTypeIInternal"] == 16 and policy["coefficientWorkers"] == 2)

    require("boundaries: identical scientific fixtures", campaigns[0]["fixturesManifestSHA256"] == campaigns[1]["fixturesManifestSHA256"])
    require("boundaries: identical frozen provenance", campaigns[0]["provenanceSHA256"] == campaigns[1]["provenanceSHA256"])

    manifest, pairs, summary = [read(model, name) for name in ("manifest.json", "pairs.json", "summary.json")]
    require("model: identical frozen provenance", manifest["provenanceSHA256"] == campaigns[0]["provenanceSHA256"])
    require("model: complete final campaign", manifest["mode"] == "final" and manifest["measuredPairs"] == 8 and len(pairs) == 4 * (8 + manifest["warmupPairs"]))
    require("model: scientific output and matched work", summary["passed"] and all(p["passed"] for p in pairs))
    profiles = summary.get("profiles", [])
    require("model: all declared profiles", len(profiles) == 4 and all(p["pairs"] == 8 for p in profiles))
    require("model: no profile regression", bool(profiles) and all(p["integrationGeometricRatio"] <= 1.03 for p in profiles), {p["profile"]: p["integrationGeometricRatio"] for p in profiles}, 1.03)
    owned_ratios = []
    for pair in pairs:
        if pair["warmup"]:
            continue
        control, candidate = pair["runs"]["control"], pair["runs"]["candidate"]
        for key in ["fullModelRetained", "fullModelMaximumLive"]:
            owned_ratios.append(candidate["livenessBytes"][key] / control["livenessBytes"][key])
    require("model: no owned-memory growth", bool(owned_ratios) and all(r <= 1 for r in owned_ratios), max(owned_ratios, default=None), 1)
    rss = summary.get("pairedBootstrap", {}).get("peakRSS", {})
    require("model: complete-lifetime RSS", bool(rss) and rss["geometricRatio"] <= 1 and rss["confidence95"][1] <= 1.03, rss, {"geometricRatio": 1, "upper95": 1.03})
    passed = all(check["passed"] for check in checks)
    return {"schema": "wvm-constant-adoption-decision-v1", "passed": passed,
            "decision": "performance gates passed; require final source/default/CI handoff" if passed else "retain frozen default",
            "checks": checks, "selectedPointwiseWorkers": selection["selectedPointwiseWorkers"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["native", "matlab", "model", "selection", "output"]:
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    result = decide(args.native, args.matlab, args.model, json.loads(args.selection.read_text()))
    with args.output.open("x") as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write("\n")
    raise SystemExit(0 if result["passed"] else 1)
