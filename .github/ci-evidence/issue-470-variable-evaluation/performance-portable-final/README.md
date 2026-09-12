# Final portable-source qualification

The frozen campaign at `5b6b5fab` **passed** after all GCC portability corrections. Runtime and test source is `5600a760`; the later commit adds exact-source qualification receipts. The separately qualified PR #469 baseline is unchanged. All local builds and tests were stopped, and macOS maintenance finished before the recorded idle-host preflight. The campaign used two warmup and eight alternating measured pairs for each profile and policy. Source, binary and fixture hashes remained unchanged through postflight. The production EddyTide experiment was untouched.

Ratios are candidate divided by baseline; below one is faster. Integration ratios are geometric means of paired observations.

| Workload | Reuse integration ratio (95% paired bootstrap interval) | Low-memory integration ratio | Reuse complete-process ratio | Low-memory peak owned storage ratio |
| --- | ---: | ---: | ---: | ---: |
| EddyTide 256 × 256 × 28 | 0.575672 [0.573523, 0.577889] | 0.575183 | 0.581882 | 1.000269 |
| Constant nonhydrostatic 256 × 256 × 129 | 1.025320 [0.995780, 1.056141] | 1.002778 | 1.002021 | 1.006186 |
| Variable Hydrostatic 256 × 256 × 129 | 0.782726 [0.777288, 0.788180] | 0.781881 | 0.836249 | 1.000067 |

EddyTide integration improved by 42.4%, and the large variable Hydrostatic case by 21.7%. The large constant case averaged 2.5% slower in integration and 0.20% slower over the complete process. Its integration interval includes both no change and a regression above 3%; the observed mean passes the investigation threshold, but does not establish a precise upper bound on slowdown. The [initial 3.08% regression and investigation](../performance-initial/README.md) and [second passing campaign](../performance-final/README.md) are retained. No pairs were excluded. The final GCC corrections preserve arithmetic order; they add direct includes, clarify lookup control flow and copy bounds, and give an existing test's pointer pairs explicit storage.

All full NetCDF scientific comparisons passed at the existing `rtol=1e-10`, `atol=1e-12` tolerances. [Baseline repeatability evidence](../baseline-repeatability.json) explains why native output comparisons are not bitwise guarantees. Integration controls, accepted/rejected-step decisions, metadata and selected output states matched exactly; error-estimator diagnostic differences are retained in `pairs.json`. Every reuse run passed both zero-duplicate execution-ledger checks and independent numerical-producer count bounds. Focused contracts assert the stronger per-context/per-key lifecycle guarantees, including low-memory failure, retry and intentional recomputation.

Low-memory peak owned storage was at most 0.62% above baseline. Retained-capacity ratios were 1.000274, 1.006568 and 1.000071, respectively, also within 3%. Low-memory integration was 42.5% faster for EddyTide, 0.28% slower for constant stratification and 21.8% faster for variable Hydrostatic. Default reuse retained more shared fields in the larger cases: peak owned storage was +16.5% for constant and +10.1% for variable Hydrostatic. Complete-process timings and peak RSS are recorded separately; RSS is not interchangeable with owned scientific storage.

The [combined Release and ASan/UBSan receipt](../cpp-contracts-final.json) records all 57 passing contracts. [Affected native checks and local GCC preflight](../cpp-portability.json) cover the subsequent portability changes. All twelve source-linked MATLAB reference/native lifecycle executions and fifteen catalog/matrix checks were refreshed at `5600a760`. The 51 Python policy tests and repository/compatibility-assembly checks pass; MATLAB scientific source is unchanged. Required hosted Linux GCC and MATLAB checks remain the integration gate.

`protocol.json`, `pairs.json` and `summary.json` preserve exact identities and all observations. Raw reports, full comparison artifacts and verified frozen copies of both executables remain in `/private/tmp/wvm471-final-performance-5b6b5fab`. The manifest and exact compact EddyTide source receipt remain in `/private/tmp/wvm-unified-evaluation-qualification`.
