# Sparse quadratic-product assessment (issue 400)

This reproducible authoring study compares linear, fixed sparse, and targeted sparse checks against a bounded dense survey of physical wave and mixed-family source products. See `REPORT.md` for findings, `API-PROPOSAL.md` for the proposed advisory interface, and `results/comparison-v1` for consolidated machine-readable evidence. Runtime defaults, coefficient shapes, physical grids, and package dependencies are unchanged.

## Reproduce

Use this authoring branch, based on WVM `9fefcc9a528de65e2f348706c45b13f741754a78`, alongside the OceanKit export at `80006f5040da787465860249f975def9831624c8` (InternalModes source `4086f978b36a4100e7419688ab355591c8253ef1`). The commands below run from the WVM repository with the export named `../wvm400-oceankit`. `configureStudyPath` adds only the pinned packages and their manifest-listed folders. On this local Apple Silicon host, MATLAB must run outside the Codex sandbox under the shared workspace policy.

For a full reproduction, first use a disposable checkout and move its published result tables aside. A fresh Git checkout contains those tables but omits the large MAT files, so it is not an empty numerical output directory. The following two setup commands preserve the published tables; do not run them in the original study working copy.

```sh
mv tools/aliasing-study/results tools/aliasing-study/results-published
mkdir tools/aliasing-study/results
```

```sh
matlab -batch "restoredefaultpath; addpath('tools/aliasing-study'); configureStudyPath('../wvm400-oceankit'); runStudyCases('calibration','tools/aliasing-study/results/calibration-v1');"
matlab -batch "restoredefaultpath; addpath('tools/aliasing-study'); configureStudyPath('../wvm400-oceankit'); runStudyCases('withheld','tools/aliasing-study/results/withheld-v1');"
matlab -batch "restoredefaultpath; addpath('tools/aliasing-study'); configureStudyPath('../wvm400-oceankit'); runReferenceRefinements('tools/aliasing-study/results/withheld-refined-v1');"
python3 tools/aliasing-study/runCostMatrix.py
matlab -batch "restoredefaultpath; addpath('tools/aliasing-study'); configureStudyPath('../wvm400-oceankit'); verifyStudyResults();"
python3 tools/aliasing-study/captureStudyProvenance.py
python3 tools/aliasing-study/assembleStudyResults.py
```

The calibration score paths have suffix `-scores-v2`; withheld and refined paths use `-scores`. Version 2 separates the quadratic-only dense count from the joint Gram/quadratic count. Historical version-1 calibration score files are preserved as superseded diagnostics; the reproduction driver writes the final version-2 paths.

On the recorded host, `verifyStudyResults` reports 12/12 study tests and 3/4 existing wave controls passing, then exits unsuccessfully on the known baseline differentiated-pressure residual check. Its replay evidence and diagnostics are written before that assertion. See `REPORT.md` and the preserved `baseline-control` logs for the identical baseline reproduction; do not interpret that exit as a successful test suite.

Run into fresh result directories as described above. Survey drivers preserve completed outputs and can resume missing scoring; cost runs refuse to overwrite partial output. Investigate any failed run before resuming. The cost matrix runs each case/policy in a fresh MATLAB process and uses macOS `/usr/bin/time -l` for process wall time and peak RSS. Run it without other numerical jobs. Assessment timings include independent validation references and measure one observation, not a statistical benchmark or optimized production implementation. The reproduction covers the final physical comparison; historical pilots remain in the preserved published tables and are described separately in `SOURCE-PILOT.md`.

## Evidence map

- `case-inventory.json`, `POLICIES.md`, and `policy-freeze.json`: predeclared cases, deterministic rules, budgets, zero count margin, and hashes frozen before withheld access.
- `reference-refinements.json`: reference-only resolution changes for two withheld pycnocline cases and a separately identified model-resolution follow-up. Original inconclusive results remain preserved.
- `results/comparison-v1`: effective case configurations, actual policy decisions, quadratic-only diagnostics, reference gates, APV controls, measured costs, larger independent-sample comparisons, and provenance.
- `results/prefix-comparison.png`: per-prefix dense/fixed/targeted errors with the common wave Gram boundary.
- `results/calibration-v1`, `results/withheld-v1`, `results/withheld-refined-v1`: original complete inventories, summary CSV/JSON, per-channel maxima, limiting input labels/signs/wavevectors, and prefix scores. Use the effective paths in `results/comparison-v1/cases.json` for final scoring.
- `results/cost-matrix-v1`: actual sparse replays, comparisons against every matching saved dense error, and fresh-process timing/memory logs. The larger independent sample uses seed 400 and 64 vector interactions without consulting sparse selections or errors.
- `SOURCE-PILOT.md`, `PLAN.md`, and `VERIFICATION.md`: scientific decisions, initial plan, and chronological verification ledger. Earlier pending statements in the ledger describe earlier checkpoints.

Full per-product MAT files are retained locally and listed with SHA-256 checksums in `results/mat-artifact-manifest.json`. Large MAT files are excluded from Git; a fresh checkout recreates them with the commands above. The source, complete bounded interaction inventories, CSV/JSON result tables, are versioned; the original scalar-control MAT is also retained locally. Exact numerical logs are preserved as gzip files under `results/raw-logs`; readable copies remove trailing whitespace only. `archiveStudyLogs.py` performs that archival step after runs terminate.

## Scope

The metric measures aliasing into retained coefficients with physical signed projections and positive error norms. It excludes exterior product content and explicitly handles structural zeros. The physical inventory contains 13 individual volume terms, eight ordered input-family pairs, both wave signs, and actual mean/inertial outputs. APV same-family assessment remains a separate control. APV/boundary output source coefficients, boundary sheet evolution, arbitrary superpositions, and full nonlinear-operator/trajectory qualification are outside the inventory. Counts are bounded by the declared candidate band and cannot certify all possible interactions.
