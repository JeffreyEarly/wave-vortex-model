# Verification ledger

Runtime source is WVM `ffb349ec500a3104a0859f1a0d578a2c1c1af9bc`, with released InternalModes beta.7 `f7f78b59f73c1f6c4052f3c5f0feb5aca7d6aa81` and OceanKit export `0f2dae987eb777dd54a15f9b910ddb7f221b5852`. Runs use MATLAB R2026a Update 5. Provider and consumer correctness/simplicity review and final scientific consistency review were performed by GPT-6 Astra at extra-high effort.

| Gate | Result | Evidence |
|---|---|---|
| Actual released provider export | 42 passing tests, including 11 new scoring tests | `provider-export.json` |
| First six focused WVM suites | 58/62; four failures corrected | `wvm-focused-tests.json` |
| Targeted corrected and additional cases | 28/28, 93.30 s | `wvm-targeted-rerun.json` |
| Consolidated latest focused results | 85 distinct tests passing; not a new full-suite run | `focused-ledger.json` |
| Release metadata | 9/9 | `release-verification.json` |
| Native MPM installation | Full declared dependency graph verified; five installed-policy tests pass | `installed-package.txt`, `installed-policy-tests.json` |
| Documentation | Build/check, zero drift; 2,649 files, 5,405 routes | `authoring-gates.txt` |
| Production Code Analyzer | 349 files, zero blocking findings | `production-analyzer-summary.json`, `production-analyzer.csv` |
| Changed tests/tools/examples analyzer | Five array-growth advisories only | `changed-authoring-analyzer.json` |
| Technical note | Three pages, no overfull boxes or broken references; all pages visually inspected | Literature `notes/quadratic-dealiasing.tex` and compiled PDF |
| Standalone figure reproduction | Identical PNG and comparison table from copied note inputs | Literature `notes/quadratic-dealiasing-data/generateFigures.py` |

The four initial failures were two updated rejection identifiers, a char/string policy restoration mismatch, and an invalid assertion treating the physical-energy getter as a separate modal invariant. The original 1e-5 physical energy time-variation criterion remains unchanged. Additional tests cover independent auto/explicit refinement, a valid APV head with an unconverged unused tail, and correctly labeled automatic zero-wave pages. Short nonlinear evolution and adaptive restart use fixed-fraction filtering; Thermal APV diagnostics/output preserve Thermal's separate quadrature algorithm.

The first installed-package attempt selected an unwritable default add-on folder under isolated MATLAB preferences. The successful rerun set the add-on installation folder to a writable temporary directory using MATLAB's own setting, then verified installed paths. User package repositories and preferences were isolated via `MATLAB_PREFDIR`. This was an environment setup correction, not a numerical or runtime change.

Production tolerances and code did not change during final calibration, the clean timing refresh, installed verification, documentation generation, or final review. Generated QG navigation-order changes follow removal/addition of public property pages. No existing released package snapshot was edited by hand. Full/exhaustive optional suites and hosted R2025b integration remain CI work for the existing open WVM PR.
