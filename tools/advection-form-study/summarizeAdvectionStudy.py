"""Audit the declared references and summarize all recorded comparisons."""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "results"

def read(name):
    with (ROOT / name).open() as stream:
        return list(csv.DictReader(stream))


def main():
    rows = []
    for profile in ("constant", "exponential"):
        for scenario in ("linear", "waves", "mixed"):
            tag = f"{profile}-{scenario}"
            reference = read(tag + "-reference.csv")[0]
            margins = [float(reference["time" + k]) + float(reference["space" + k]) for k in ("Velocity", "Density", "SSH")]
            data = read(tag + "-trajectories.csv")
            for level, target in enumerate(((1e-3, 1e-3, 1e-2), (1e-4, 1e-4, 1e-3), (1e-5, 1e-5, 1e-4)), 1):
                qualified = all(float(reference[p + k]) < tol / 4 for p in ("time", "space") for k, tol in zip(("Velocity", "Density", "SSH"), target))
                for form in ("divergence", "advective", "split", "compatible"):
                    base = next(r for r in data if r["form"] == form and r["config"] == "1" and r["deltaT"] == "20")
                    score = max((float(base[k]) + margin) / tol for k, margin, tol in zip(("velocityError", "densityError", "sshError"), margins, target))
                    rows.append(dict(profile=profile, scenario=scenario, target=level, form=form, referenceQualified=qualified, smallGridErrorScore=score, smallGridMeetsTarget=qualified and score <= 1))
    with (ROOT / "matched-targets.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=rows[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"{len(rows)} target/form cases; {sum(r['smallGridMeetsTarget'] for r in rows)} meet targets on 8x8x33 at dt20.")
    for name in ("sources.csv", "families.csv", "long-trajectories.csv", "budgets.csv", "rhs-timings.csv"):
        print(name, len(read(name)))


if __name__ == "__main__":
    main()
