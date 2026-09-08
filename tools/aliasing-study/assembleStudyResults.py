"""Assemble the final study tables from preserved, completed numerical runs."""
import csv
import hashlib
import json
import re
from pathlib import Path

STUDY = Path(__file__).resolve().parent
RESULTS = STUDY / "results"


def read_json(path):
    return json.loads(path.read_text())


def read_csv(path):
    with path.open(newline="") as stream:
        return list(csv.DictReader(stream))


def write_csv(path, rows):
    with path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def case_registry():
    inventory = read_json(STUDY / "case-inventory.json")
    registry = []
    for split in ["calibration", "withheld"]:
        for case in inventory[split]:
            refined = case["profile"] == "pycnocline"
            root = "withheld-refined-v1" if refined else f"{split}-v1"
            suffix = "-scores-v2" if split == "calibration" else "-scores"
            registry.append(dict(caseId=case["id"], split=split,
                                 dense=f"{root}/{case['id']}",
                                 scores=f"{root}/{case['id']}{suffix}"))
    case = read_json(STUDY / "reference-refinements.json")["followup"]
    registry.append(dict(caseId=case["id"], split="resolution-followup",
                         dense=f"withheld-refined-v1/{case['id']}",
                         scores=f"withheld-refined-v1/{case['id']}-scores"))
    return registry


def process_cost(name):
    text = (RESULTS / "cost-matrix-v1" / f"{name}.time.log").read_text()
    wall = re.search(r"([\d.]+) real\s+([\d.]+) user\s+([\d.]+) sys", text)
    memory = re.search(r"(\d+)\s+maximum resident set size", text)
    if not wall or not memory:
        raise ValueError(f"Incomplete process timing: {name}")
    return dict(processWallSeconds=float(wall[1]), peakResidentBytes=int(memory[1]))


def main():
    freeze = read_json(STUDY / "policy-freeze.json")
    for name, digest in freeze["selectionRuleFiles"].items():
        assert hashlib.sha256((STUDY / name).read_bytes()).hexdigest() == digest, name
    registry = case_registry()
    output = RESULTS / "comparison-v1"
    output.mkdir(exist_ok=True)
    decisions, quadratic, references, costs, controls = [], [], [], [], []
    for case in registry:
        case_id = case["caseId"]
        summary = read_json(RESULTS / case["dense"] / "summary.json")
        assert summary["referencesStable"], case_id
        case["configuration"] = summary["configuration"]
        interactions = read_csv(RESULTS / case["dense"] / "interactions.csv")
        vectors = [tuple(int(row[key]) for key in ["k1x", "k1y", "k2x", "k2y", "k3x", "k3y"]) for row in interactions]
        assert len(set(vectors)) == len(vectors) == summary["interactionCount"], case_id
        assert all(v[0] + v[2] == v[4] and v[1] + v[3] == v[5] for v in vectors), case_id
        products = read_csv(RESULTS / case["dense"] / "products.csv")
        assert sum(int(row["productCount"]) for row in products) == summary["nonzeroProductEvaluations"], case_id
        assert sum(int(row["zeroProductCount"]) for row in products) == summary["structuralZeroProducts"], case_id
        assert len(read_csv(RESULTS / case["dense"] / "channels.csv")) == 13, case_id
        for name, collection in [("scores.csv", decisions), ("quadratic-diagnostics.csv", quadratic)]:
            for row in read_csv(RESULTS / case["scores"] / name):
                collection.append(dict(caseId=case_id, split=case["split"], **row))
        references.append(dict(caseId=case_id, split=case["split"], **{
            key: summary[key] for key in ["referencesStable", "fixedFamiliesGramAccepted",
                "referenceStability", "eigenConvergence", "eigenProductStability",
                "boundaryInterpolationError", "apvGram", "mdaGram", "inertialGram",
                "interactionCount", "nonzeroProductEvaluations", "structuralZeroProducts",
                "constructionSeconds", "assessmentSeconds"]}))
        for row in summary["apvControl"]:
            controls.append(dict(caseId=case_id, **row))
        for policy in ["linear", "fixed", "targeted"]:
            name = f"{case_id}--{policy}"
            cost = read_json(RESULTS / "cost-matrix-v1" / name / "cost-summary.json")
            if policy == "linear":
                case["familyModeLabels"] = cost["familyModeLabels"]
            if policy != "linear":
                verification = read_json(RESULTS / "cost-matrix-v1" / name / "replay-verification.json")
                assert verification["status"] == "passed", name
            costs.append(dict(caseId=case_id, split=case["split"], policy=policy,
                              **{key: cost[key] for key in ["constructionSeconds", "assessmentSeconds", "nonzeroProductEvaluations"]},
                              **process_cost(name), denseEvaluations=summary["nonzeroProductEvaluations"],
                              evaluationFraction=cost["nonzeroProductEvaluations"] / summary["nonzeroProductEvaluations"]))
    for name, rows in [("decisions", decisions), ("quadratic-diagnostics", quadratic),
                       ("references", references), ("costs", costs), ("apv-control", controls)]:
        write_csv(output / f"{name}.csv", rows)
    inventory = read_json(STUDY / "case-inventory.json")
    large_id = inventory["larger"]["id"]
    large = {}
    for policy in ["linear", "fixed", "targeted", "independent"]:
        name = f"{large_id}--{policy}"
        directory = RESULTS / "cost-matrix-v1" / name
        large[policy] = read_json(directory / "cost-summary.json")
        large[policy].update(process_cost(name))
        if policy != "linear":
            large[policy]["prefixes"] = read_csv(directory / "sampled-prefixes.csv")
    selected = {policy: {int(row["interaction"]) for row in read_csv(
        RESULTS / "cost-matrix-v1" / f"{large_id}--{policy}" / "products.csv")}
        for policy in ["fixed", "targeted", "independent"]}
    assert selected["independent"] == set(large["independent"]["independentInteractionIndices"])
    assert len(selected["independent"]) == inventory["larger"]["independentSampleCount"]
    large["coverage"] = dict(totalValidInteractions=len(read_csv(
        RESULTS / "cost-matrix-v1" / f"{large_id}--fixed" / "interactions.csv")),
        selectedCounts={key: len(value) for key, value in selected.items()},
        independentOverlap={key: len(selected[key] & selected["independent"]) for key in ["fixed", "targeted"]},
        independentSeed=inventory["larger"]["independentSampleSeed"])
    comparisons = []
    for policy in ["fixed", "targeted"]:
        for i, tolerance in enumerate([0.1, 0.03, 0.01]):
            for gate, key in [("joint", "largestSampledCounts"), ("quadratic-only-diagnostic", "largestQuadraticOnlyCounts")]:
                count = large[policy][key][i]
                observed = max([float(r["sampledQuadraticError"]) for r in large["independent"]["prefixes"][:count]], default=0)
                qualified = large[policy]["referencesStable"] and large["independent"]["referencesStable"]
                if gate == "joint":
                    qualified = qualified and large[policy]["fixedFamiliesGramAccepted"]
                comparisons.append(dict(policy=policy, gate=gate, tolerance=tolerance,
                                        largestSampledCount=count, independentMaximumThroughCount=observed,
                                        qualified=qualified, observedFailure=observed > tolerance if qualified else "inconclusive"))
    write_csv(output / "larger-comparison.csv", comparisons)
    (output / "larger.json").write_text(json.dumps(large, indent=2) + "\n")
    (output / "cases.json").write_text(json.dumps(registry, indent=2) + "\n")
    (output / "provenance.json").write_text(json.dumps(dict(
        policyFreezeVerified=True, machine=read_json(RESULTS / "machine.json"),
        wvmBase="9fefcc9a528de65e2f348706c45b13f741754a78",
        oceanKit="80006f5040da787465860249f975def9831624c8",
        internalModes="4086f978b36a4100e7419688ab355591c8253ef1",
        scalarMetricControl="../pilot-01", timingReplicates=1,
        timingScope="fresh process per case/policy; shared mode/reference construction reported separately; includes validation references",
        rawProducts="Local products.mat files are reproducible and listed in ../mat-artifact-manifest.json; large binaries are excluded from Git."), indent=2) + "\n")
    print(f"Assembled {len(registry)} cases, {len(decisions)} decisions, {len(costs)} cost measurements and the independent larger sample.")


if __name__ == "__main__":
    main()
