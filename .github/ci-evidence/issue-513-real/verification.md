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

| Combined native suite | Reviewed combined source | 59/59 pass (21.13 s), warning-clean Clang build | Runtime/native-test edits |
| Combined focused MATLAB | Reviewed combined source; existing odd grids plus new even-grid analytic/integral cases | 14 final methods pass: 12 unchanged successful methods reused, changed/new two methods rerun and pass | Relevant runtime/test edits |
| Source-selection receipt | Current kernel SHA | Focused hash contract passes; corrects #519 CI failure | Kernel source edits |
| Even-grid low-mode diagnostic | Nonantialiased fourth derivatives | Frozen baseline and candidate show the same pre-existing MATLAB-matrix discrepancy; direct probe outputs are bitwise equal | Runtime/probe changes |
| Code Analyzer | New primitive harness and updated test | Two benign NASGU warnings for explicit cleanup; no correctness findings | MATLAB edits |
| CI-policy tests | Current routing/policy | 52/52 pass | Routing/policy edits |

The originally added low-mode even-grid stress case produced fourth-derivative relative differences to MATLAB of approximately 1.43e-12 (F) and 1.89e-12 (G), identically on #519 and candidate. Its failed diagnostics are retained. No tolerance was loosened. Existing odd-grid test inputs remain unchanged; the added even-grid regression test uses independently differentiated retained modes 6 and 3 at 1e-12, and even-grid matrix integrals remain covered. A separate low-mode probe also verifies candidate/baseline agreement directly (bitwise equal).
