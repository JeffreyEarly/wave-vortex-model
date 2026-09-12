# Final unified-evaluation qualification

The frozen campaign at `29c80e7c` **passed**. Runtime implementation source is `4d8dbf37`; the later commit adds qualification receipts. The separately qualified PR #469 baseline is unchanged. The idle-host campaign used two warmup and eight alternating measured pairs for each profile and policy. `protocol.json` records exact source, binary, fixture and environment identities, `pairs.json` records every run, and `summary.json` records the acceptance result. Source and executable hashes remained unchanged through postflight. The production experiment was untouched.

Ratios below are candidate divided by baseline; less than one is faster. Integration ratios are geometric means of paired observations.

| Workload | Reuse integration ratio (95% paired bootstrap interval) | Low-memory integration ratio | Reuse complete-process ratio | Low-memory peak owned storage ratio |
| --- | ---: | ---: | ---: | ---: |
| EddyTide 256 × 256 × 28 | 0.571564 [0.569303, 0.573728] | 0.574482 | 0.577536 | 1.000269 |
| Constant nonhydrostatic 256 × 256 × 129 | 1.016902 [0.988132, 1.042963] | 1.013696 | 1.003731 | 1.006186 |
| Variable Hydrostatic 256 × 256 × 129 | 0.776365 [0.770361, 0.782725] | 0.774503 | 0.830732 | 1.000067 |

EddyTide integration improved by 42.8%, and the large variable Hydrostatic case by 22.4%. The large constant case averaged 1.7% slower in integration and 0.37% slower over the complete process. Its wider integration interval includes both no change and a regression above 3%; this campaign establishes a mean below the investigation threshold, not a precise upper bound on slowdown. The [initial campaign](../performance-initial/README.md) and its 3.08% regression are preserved. Investigation led to guarded parallel coefficient validation with existing workers and removal of repeated finite/phase scans for exact validated scopes. No scientific algorithm or forcing accumulation order changed.

All NetCDF scientific comparisons passed at the existing `rtol=1e-10`, `atol=1e-12` tolerances. The [baseline repeatability evidence](../baseline-repeatability.json) explains why native-backend comparisons cannot require bitwise equality; accepted/rejected steps, integration controls, metadata and selected output states matched exactly. Normalized-error diagnostic differences are reported separately in the pairs. Every reuse run passed both the zero-duplicate execution-ledger gate and the independent numerical-producer count bounds. Focused contracts provide per-context and per-key assertions, including low-memory failure/retry and explicit eviction/recomputation.

Low-memory maximum live owned storage was at most 0.62% above baseline. Its retained-capacity ratios were 1.000274, 1.006568 and 1.000071, respectively, also within 3%. Default reuse deliberately retained more shared fields on the larger cases: peak owned-storage ratios were 1.165474 (constant) and 1.100526 (variable Hydrostatic). Low-memory runtime trade-offs are shown separately; it was statistically similar to reuse in these workloads. Full reports also include process peak RSS, which is not interchangeable with owned scientific storage.

All 57 C++ contracts passed in Release and ASan/UBSan at the runtime source commit. Twelve MATLAB reference/native forward-integration receipts, eight catalog tests, seven compatibility-matrix tests and 51 Python policy tests passed. See [the final C++ receipt](../cpp-contracts-final.json), [MATLAB results](../matlab-results.json), and [the verification ledger](../../../planning/issue-470-verification.md).

Raw reports, comparison artifacts and frozen copies of both executables remain in `/private/tmp/wvm470-final-performance-29c80e7c`. The immutable manifest and compact EddyTide source receipt remain in `/private/tmp/wvm-unified-evaluation-qualification`.

Hosted GCC compilation subsequently exposed a missing direct `<array>` include. Commit `dbdafe24` adds that include to six headers that use `std::array`. All 52 native kernel/runtime compilation objects are byte-identical before and after this portability correction; [the object-by-object receipt](../native-include-equivalence.json) establishes that the measured numerical code is unchanged. Archive container hashes changed during rebuilding and are not claimed to be identical. Exact-source MATLAB qualification is refreshed for the corrected headers; another native performance campaign is unnecessary for unchanged compilation objects.
