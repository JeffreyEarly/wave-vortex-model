"""Build the technical note's figure and tables from recorded measurements.

Usage: python generateFigures.py RESULTS_ROOT NOTE_DATA_DIRECTORY
Requires matplotlib; performs no numerical-mode solves or timing runs.
"""

import csv
import json
from pathlib import Path
import shutil
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


def main(results_root, destination):
    destination.mkdir(parents=True, exist_ok=True)
    benchmark = json.loads((results_root / "construction/summary.json").read_text())
    calibration = list(csv.DictReader((results_root / "calibration/calibration.csv").open()))
    names = {"none": "None", "fixedFraction": "Fixed fraction", "effectiveBandwidth": "Effective bandwidth"}
    colors = {"none": "#536171", "fixedFraction": "#007c91", "effectiveBandwidth": "#c15b24"}
    styles = {"none": "-", "fixedFraction": "--", "effectiveBandwidth": ":"}
    fig, ax = plt.subplots(figsize=(7.0, 2.6), layout="constrained")
    table_rows = []
    for entry in benchmark["policies"]:
        policy = entry["policy"]
        if entry["status"] != "constructed":
            raise ValueError(f"Cannot graph a rejected construction: {policy}")
        counts_path = results_root / "construction" / f"{policy}-counts.csv"
        counts = list(csv.DictReader(counts_path.open()))
        kappa = [float(row["kappa"]) for row in counts]
        waves = [int(row["waveCount"]) for row in counts]
        apv = int(counts[0]["apvCount"])
        ax.plot(kappa, waves, color=colors[policy], linestyle=styles[policy], linewidth=2,
                label=f"{names[policy]} (APV {apv})")
        selected = [row for row in calibration if row["policy"] == policy
                    and abs(float(row["retainedFraction"]) - 2 / 3) < 1e-10
                    and abs(float(row["energyFraction"]) - .99) < 1e-10
                    and abs(float(row["bandwidthFraction"]) - 2 / 3) < 1e-10
                    and int(row["sampleCount"]) > 0]
        error = max(float(row["maximumAliasError"]) for row in selected)
        table_rows.append(f"{names[policy]} & {entry['medianSeconds']:.2f} & "
                          f"{1000 * entry['medianFilteringSeconds']:.1f} & {100 * error:.3g}\\% \\\\")
        shutil.copy2(counts_path, destination / counts_path.name)
    ax.set_xscale("log")
    ax.set_xlabel(r"Horizontal wavenumber $k$ (m$^{-1}$)")
    ax.set_ylabel("Retained wave modes")
    ax.grid(alpha=.22)
    ax.legend(frameon=False, loc="best", fontsize=9)
    fig.savefig(destination / "retained-modes.pdf")
    fig.savefig(destination / "retained-modes.png", dpi=180)
    plt.close(fig)
    table = "\n".join([
        r"\begin{center}",
        r"\begin{tabular}{lrrr}",
        r"\toprule",
        r"Policy & Construction (s) & Filtering (ms) & Sampled maximum error \\",
        r"\midrule",
        *table_rows,
        r"\bottomrule",
        r"\end{tabular}",
        r"\end{center}",
        "",
    ])
    (destination / "comparison-table.tex").write_text(table)
    for filename in ["calibration.csv", "summary.json"]:
        shutil.copy2(results_root / "calibration" / filename, destination / f"calibration-{filename}")
    shutil.copy2(results_root / "construction/summary.json", destination / "construction-summary.json")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
