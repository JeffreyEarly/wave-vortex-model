# Historical sparse quadratic-product study

This directory preserves the frozen evidence from the issue 400 sampled-product study. The diagnostic and its reusable WVM wrappers were retired in issue 42 after free-surface construction adopted the simpler `quadraticDealiasing` policies. The MATLAB and Python drivers have been removed, so this archive is not a runnable or current API guide.

The recorded tables retain their original field names and numerical values. Their provenance identifies the exact WVM, OceanKit, and InternalModes revisions used to produce them; use those revisions from repository history if exact reproduction is required. Current construction behavior and evidence are documented in [automatic mode selection](../../Documentation/Validation/AutomaticModeSelection.md) and the [quadratic-dealiasing study](../quadratic-dealiasing-study/README.md).

## Evidence map

- `case-inventory.json`, `POLICIES.md`, and `policy-freeze.json`: predeclared cases and historical sampling rules.
- `reference-refinements.json`: historical reference-only refinements.
- `results/comparison-v1`: consolidated configurations, decisions, errors, costs, and provenance.
- `results/calibration-v1`, `results/withheld-v1`, and `results/withheld-refined-v1`: frozen detailed product-survey outputs.
- `results/cost-matrix-v1`: historical replay timing and memory logs.
- `SOURCE-PILOT.md`, `PLAN.md`, `REPORT.md`, and `VERIFICATION.md`: the original scientific decisions, findings, and verification ledger.

Large MAT files remain excluded from Git. The versioned CSV, JSON, plots, compressed logs, and manifests are retained as historical evidence.
