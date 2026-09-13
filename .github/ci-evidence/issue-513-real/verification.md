# Issue 513 second-stage verification ledger

Baseline: PR #519 at 81692f49a98ceb7b5ef75f345fb5567494eb8b86, runtime aggregate 7cfa4cc82f7f1daec6afcc0b870be8210e4ba6aa4656f15998c79ef2adeea92a. Work occurs in isolated `wvm-v4-issue513-real`; the original v5 checkout, prior worktrees and frozen archives are unchanged.

Original endpoint/composite NetCDF fixture payloads remain absent. This increment reuses the exact reconstructed fixture hashes from the first investigation; no fixture recipe change or reconstruction was needed.

Prior spectral-kernel-benchmarks history and decisions recorded in the first report remain applicable. This increment measures redundant per-column multiplier work and the unused imaginary lane in MATLAB vertical calculus, not a new provider or tracer architecture.

Go/no-go: at least 10% lower composite median against #519, no coefficient endpoint regression above 3%, all numerical/control/output checks at existing tolerances. Diagnostics are not qualification. Three fresh processes per frozen configuration/workload on an idle host; retain every sample.

| Gate | Identity | Result | Invalidated by |
| --- | --- | --- | --- |
| PR #519 Linux C++ | 81692f49 | Release and sanitizer builds pass | Runtime/toolchain changes |
| PR #519 MATLAB CI | 81692f49 | Two smoke jobs found stale source-selection kernel hash; correction included in this increment | Corrected source-linked receipt and focused test |
| Diagnostic attribution | Instrumented #519 algorithm, archived patch/module | 160 calls: multiplier 5.179 s, transforms 4.749 s, packing 1.040 s, normalization 0.693 s | Workload/algorithm changes |
| Multiplier-only native | Per-operation factors with original arithmetic | Three focused primitive contracts pass | Multiplier/runtime edits |
| Real-only native | Contiguous real batched plans, original per-column factors | Constant primitive contract passes | Plan/normalization/runtime edits |
| Independent source review | Planned combined source | No actionable arithmetic, stride, extent, endpoint or allocation findings | Runtime edits |

No exact active-time split between implementation, verification and waiting has been measured. Process lifetimes and integration durations are recorded separately by the campaign runner.

| Gate | Identity | Result | Invalidated by |
| --- | --- | --- | --- |
| Combined native suite | Reviewed combined source | 59/59 pass (21.13 s), warning-clean Clang build | Runtime/native-test edits |
| Combined focused MATLAB | Reviewed combined source; existing odd grids plus new even-grid analytic/integral cases | 14 final methods pass: 12 unchanged successful methods reused, changed/new two methods rerun and pass | Relevant runtime/test edits |
| Source-selection receipt | Current kernel SHA | Focused hash contract passes; corrects #519 CI failure | Kernel source edits |
| Even-grid low-mode diagnostic | Nonantialiased fourth derivatives | Frozen baseline and candidate show the same pre-existing MATLAB-matrix discrepancy; direct probe outputs are bitwise equal | Runtime/probe changes |
| Code Analyzer | New primitive harness and updated test | Two benign NASGU warnings for explicit cleanup; no correctness findings | MATLAB edits |
| CI-policy tests | Current routing/policy | 52/52 pass | Routing/policy edits |

The originally added low-mode even-grid stress case produced fourth-derivative relative differences to MATLAB of approximately 1.43e-12 (F) and 1.89e-12 (G), identically on #519 and candidate. Its failed diagnostics are retained. No tolerance was loosened. Existing odd-grid test inputs remain unchanged; the added even-grid regression test uses independently differentiated retained modes 6 and 3 at 1e-12, and even-grid matrix integrals remain covered. A separate low-mode probe also verifies candidate/baseline agreement directly (bitwise equal).

The frozen combined runtime is commit 8a1840a3129a3aed62efd8e4ac6277bdf063e873, aggregate 209a99eeda112d7b4106821c859eba619a8f2745f44489dc4ed6fb2d8af81700 and MEX SHA-256 414f573ce55b427dbb23d48f32b7f5bf986a9c921a8783d31986ebf83100e189. Linux release and sanitizer builds pass on CI run 34774291513. MATLAB smoke passes on both releases after the source-selection correction. Subsequent full/sanitized shards expose a separate stale digest in the committed forward-integration receipts; the detailed assertion is preserved. The existing lifecycle collector refreshed those receipts with fresh executions and content-addressed evidence, without changing the validator or runtime.

Frozen timing qualification passes: selected baseline/candidate composite medians 49.1195145/41.7695603 s (14.9634% reduction), endpoint 14.6090016/14.3785760 s (1.5773% reduction). All sixteen integration observations are retained: twelve original, three baseline-only idle supplements, one pre-supplement inspector failure. Three original baseline observations are excluded solely for post-run host snapshots. All 29 full-output/repeatability/control comparisons pass at 1e-13 + 1e-12 times reference scale; metadata and times are exact. Maximum absolute error 1.81899e-12 occurs in particle positions and also within candidate repeatability; maximum relative coefficient error 1.06219e-12 has absolute error 1.23512e-14 and passes the unchanged combined tolerance. All per-workload controls, tolerance hashes, work counts, complete runtime counters and counter deltas are exactly equal.

Required forward-integration receipt refresh: fresh native-capable runner/probe at frozen source 8a1840a3, six lifecycle methods / twelve provider cases pass (254.85 s summed test duration), then the previously failing committed receipt contract passes (0.172 s). Previous receipt pointers are backed up in the raw evidence; existing content-addressed fragments are unchanged and twelve new fragments are retained. This refresh is a required source-provenance gate, not a publication performance campaign. Final changes after timing affect evidence/receipt files only; runtime source and MEX stay frozen.

A first lifecycle-helper invocation failed before tests because its hyphenated script filename was interpreted incorrectly by MATLAB. The successful retry uses refreshForwardIntegrationReceipts.m. The original failed-invocation log was overwritten by that retry; a clearly labeled reconstruction from the tool transcript is retained in the raw archive. No timing sample was overwritten.

Archive verification: 326 files / 8,934,152,661 bytes; manifest ac05175ad0e5ed2a4aa5a1f79a3f5b14e383a53272febe36f197c92419871071. Both frozen source tarballs match all 319 source-manifest file hashes; archived baseline/candidate modules and common provider libraries match qualification. Prior manifest remains 420a99e552fbb773fc40c609562269ad48eb8ef1013bf09ca035a7dd02bad937.

Final repository/compatibility checks pass (1754 rows, 75 witnesses). The committed focused-test CSV was normalized to LF after the staged whitespace check flagged CRLF; its original raw bytes remain archived. Final staged whitespace and evidence-only scope checks pass. No runtime, test implementation, generated website, package manifest or snapshot changed after the performance freeze.

Merge preparation and benchmark-page annotation: all required CI checks passed on 078f58f5 (run 34776429540). Strict branch protection required incorporating main through c2898d0e, which adds the already-published v4.4.0 table and benchmark failure-retention fixes. All 319 qualified runtime source files still match the frozen candidate manifest. A canonical benchmark-page note reports the separate optimization qualification and its reconstructed-fixture/memory limits; published datasets and table values are preserved. Documentation was generated once; the existing current-model selector test passes; docs:check passes with 2055 files, 4200 routes and zero differences. No new benchmark campaign or runtime qualification was needed for this documentation/integration step. Normal required CI must pass again before merge.
