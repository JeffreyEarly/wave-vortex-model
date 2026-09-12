# Final corrected-source qualification

The frozen campaign at `3f2b3639` **passed**, including the density-lifetime and component-energy corrections in runtime source `45107911`. The separately qualified PR #469 baseline is unchanged. All builds and tests were stopped before the recorded idle-host preflight. Two warmup and eight alternating measured pairs were run for each profile and policy. Source, binary and fixture hashes remained unchanged through postflight. The production EddyTide experiment was untouched.

Ratios are candidate divided by baseline; below one is faster. Integration ratios are geometric means of paired observations.

| Workload | Reuse integration ratio (95% paired bootstrap interval) | Low-memory integration ratio | Reuse complete-process ratio | Low-memory peak owned storage ratio |
| --- | ---: | ---: | ---: | ---: |
| EddyTide 256 × 256 × 28 | 0.573006 [0.571639, 0.574288] | 0.573247 | 0.578891 | 1.000270 |
| Constant nonhydrostatic 256 × 256 × 129 | 1.003252 [0.992900, 1.014216] | 1.002873 | 1.000502 | 1.006186 |
| Variable Hydrostatic 256 × 256 × 129 | 0.784468 [0.779821, 0.789308] | 0.783646 | 0.837383 | 1.000067 |

EddyTide integration improved by 42.7%, and variable Hydrostatic by 21.6%. The large constant case averaged 0.3% slower in integration and 0.05% slower over the complete process; its integration interval includes no change. The [initial 3.08% regression and investigation](../performance-initial/README.md), [second campaign](../performance-final/README.md), and [third campaign](../performance-portable-final/README.md) remain historical evidence. No pairs were excluded.

All full NetCDF scientific comparisons passed at existing `rtol=1e-10`, `atol=1e-12` tolerances. [Baseline repeatability evidence](../baseline-repeatability.json) explains why native output comparisons are not bitwise guarantees. Integration controls, accepted/rejected-step decisions, metadata and selected output states matched exactly; error-estimator diagnostic differences remain in `pairs.json`. Every reuse run passed zero-duplicate execution-ledger checks and independent numerical-producer count bounds. Focused contracts assert per-context/per-key lifecycle guarantees, including low-memory failure, retry and intentional recomputation.

Low-memory peak owned storage was at most 0.62% above baseline. Retained-capacity ratios were 1.000275, 1.006568 and 1.000071, respectively, also within 3%. Low-memory integration was 42.7% faster for EddyTide, 0.29% slower for constant stratification and 21.6% faster for variable Hydrostatic. Default reuse retains more shared fields in the larger cases: peak owned storage was +16.5% for constant and +10.1% for variable Hydrostatic. Complete-process timings and peak RSS are recorded separately; RSS is not interchangeable with owned scientific storage.

All 57 native contracts pass in both Release and ASan/UBSan at the corrected source; [combined receipt](../cpp-contracts-corrected.json). The [diagnostic correction receipt](../diagnostic-corrections.json) covers hardened allocation-failure retry and affected MATLAB density/diagnostic parity. Twelve exact-source reference/native forward executions and fifteen catalog/matrix checks pass. MATLAB production/scientific code is unchanged; one C++ memory-accounting assertion in a MATLAB test was corrected. Required hosted checks remain the integration gate.

`protocol.json`, `pairs.json` and `summary.json` preserve identities and all observations. Raw reports, complete comparisons and hash-verified frozen copies of both executables remain in `/private/tmp/wvm471-corrected-performance-3f2b3639`. The manifest and compact EddyTide source receipt remain in `/private/tmp/wvm-unified-evaluation-qualification`.
