# Prepared RHS benchmark and pipeline screen (#495)

Baseline: merged PR #494, `f65ebf684a403742ed27775de0a2c2aac4a1e2fe`. Required CI passed; #493 closed. The clean v4 main checkout was fast-forwarded. Original benchmark/evidence worktrees and all v5/experiment worktrees are retained untouched.

## Scope and ownership

Root owns compute, candidate source and qualification. One existing implementation worker owns `Benchmarks/prepared-pipeline/`; one independent reviewer audits the pipeline and prior benchmark history. No agent builds or benchmarks concurrently.

The prepared worker measures nonlinear flux plus physical field construction. It deliberately excludes damping, integrators and outputs. Each call starts/ends a fresh evaluation, while immutable matrices, plans and capacity persist. Benchmark validation occurs outside timing and retains source/provider/input identities. This screen cannot establish whole-model gains.

## Verification ledger

- Initial applicable guides: repository AGENTS, C++ optimization workflow, shared caching/profiling/documentation guides read.
- Source/CI: #494 merged and required checks passed; clean source at `f65ebf68`.
- Disk preflight: approximately 5.3 GiB free; no full NetCDF output copies planned for stage screen.
- Existing helper and benchmark review: previous adoption workers already load once, but do not select the current tiled path or use explicit state scopes. New driver adapts their construction/receipt conventions and adds sequential resident-worker commands.
- Host observation at 19:54 UTC: no active experiment/build/MATLAB observed; only Codex exceeds 10% CPU. Recheck and journal during timings.

## Frozen candidate and focused qualification

Runtime and harness frozen at `ed6049a2504dad833e93c9221b66ea68db1ac404`. The runner and forward probe were relinked after freezing and their embedded commit independently verified with `strings`. Evidence commits do not change these compiled inputs. Large artifacts remain in `wave-vortex-model-benchmark-artifacts/prepared-pipeline-20260912/` relative to the workspace root.

| Gate | Result | Invalidation condition |
| --- | --- | --- |
| PortableRuntime Release | 50/50 pass | Runtime, compiler or provider change |
| Compiled-kernel contracts | 8/8 pass | Kernel, compiler or provider change |
| H/B kernel and prepared executor ASan/UBSan | 3/3 pass; leak detection disabled | Affected runtime change |
| Changed H/B units, GCC 14 | Warning-clean source with explicit macOS 26.5 SDK; unrelated deployment-target warning | Affected source or toolchain change |
| Stored-pass projection oracle | Exact bits under Clang and GCC, both `hasW` paths and edge operands | Projection arithmetic change |
| Python resident driver | 6 tests pass with NumPy and stdlib fallback | Harness change |
| Focused MATLAB parity/integration | 14/14 pass | Scientific/runtime/reference change |
| Forward/restart lifecycle | All six configurations pass with reference and native providers | Runtime, lifecycle or scientific reference change |

Independent review checked disjoint writes, joined cache publication, matrix scratch lifetime, forcing/cache behavior, and stored-divergence arithmetic. It requested physical-field comparisons and explicit failed receipts in the resident driver; these were implemented and tested before source freeze. Intermediate Clang include and GCC default-SDK build errors were corrected before qualification. There were no tolerance changes.

Four resident screens retained the fusion-only, projection-parallel, final Boussinesq-assembly, and Hydrostatic-projection variants. The strengthened final screens compare complete flux and physical-field payloads, producer counters and storage. Full-model acceptance is a separate campaign against the exact accepted #494 executable; timings and raw host activity are preserved without editing the running experiment or host services.

No successful gate is repeated without a relevant source or input change. Production MATLAB and generated website content are unchanged.


## Delivery checkpoint

- Strict forward receipt catalog: 8/8 pass after collecting actual frozen runner/probe evidence. Repository boundaries, compatibility provenance and CI registration pass (1,754 rows, 75 witnesses). No generated compatibility changes were required.
- Resident screens: cumulative Boussinesq RHS ratio 0.88192 and Hydrostatic ratio 0.92522, unchanged storage/producers. Full Boussinesq resident screen, including load/preparation and validation, takes approximately 44 seconds. These remain stage results, distinct from full integration.
- Full-model campaign: 20:22:45–20:34:05 UTC, 22 complete scientific comparisons pass. EddyTide and larger Hydrostatic complete eight measured pairs each (provisional ratios 0.93854 and 0.98628); Boussinesq completes its two correctness warmup pairs. All completed pairs preserve exact controls, producer records and owned memory. Background host activity invalidates clean timing acceptance. Stop remaining repeats; preserve the partial first Boussinesq measured run and explicit operator-stop record. No production adoption or auto-merge until quiet-host timing passes.
- Two supporting agents handled benchmark implementation and independent review; root alone scheduled compute. Prepared variant screens cost seconds rather than repeated persisted-matrix loading. Approximately the first 35 minutes covered profiling, harness/loop implementation, review, compiler checks and MATLAB parity; forward qualification and the 11.3-minute interrupted timing campaign followed. These chronological intervals are approximate and not an exact active-work accounting.
- Next work reuses the frozen runtime and all valid correctness gates, runs disposable full-model outputs outside the indexed workspace, observes the host between pairs, and stops promptly on contamination. No need to repeat broad scientific checks for timing-only work. See [results and adoption limits](../../Benchmarks/prepared-pipeline/RESULTS.md).


## Final integration and website audit (September 12)

- #497 merged as `280afe5b` with required CI passing; #488 closed. Integrated its guard into this branch as `2fe52331`. Only forward-receipt indexes conflicted; collected new executed receipts after integration instead of carrying stale source fingerprints. No compiled runtime inputs changed from frozen `ed6049a2`.
- Final complete-model campaign: 23:10:21–23:33:36 UTC, 30/30 comparisons pass. Two warmups plus eight alternating measured pairs per original fixture. Integration ratios: EddyTide 0.93219, larger Hydrostatic 0.98515, Boussinesq 0.89103. No integration or complete-process point estimate triggers the >3% regression gate; no owned-memory growth and producer records identical. Per-process idle checks passed, but intermittent desktop activity remained. The final adoption decision retains all pairs, order sensitivity and the resident evidence; it does not claim a perfectly isolated host. Boussinesq is especially order-sensitive (0.99187 baseline-first, 0.80044 candidate-first), so its aggregate is not a stable production-speedup guarantee. See final machine-readable results and host journal links in the report. The original stopped campaign remains preserved.
- Disk preflight initially stopped before any execution. Reclaimed the completed reproducible `/private/tmp/wvm489-sanitized` build tree after retaining its CMake configuration. Scientific fixtures, running experiments and v5 worktrees were untouched. Final disposable pair outputs were hashed and removed only after successful comparison; all compact evidence and binaries are archived.
- Fresh integrated guard qualification: all six forward configurations pass with both providers; ten strict receipt/catalog tests pass. Actual runner/probe revisions match `ed6049a2` via the clean frozen source root. No new C++ rebuild or repeat of already-passing compiler/numerical suites was needed.
- Repository provenance and boundaries pass: 1,754 rows and 75 witnesses. #307/#310 were updated to remove completed sampling/density gaps and retain the precise final-source ATS/export qualification gate. No formal standard-parity declaration was made.
- Owner-authorized website audit separates historical interface/scaling data from the new dated native measurements. Selected record provenance is generated, fixed winner claims removed, and builtin storage/RSS scopes separated. Missing Aug 27/28 M5 raw archives are explicitly reported in the audit; normalized public results are present.
- Documentation verification pending below. Initial focused run passed 9/10; the new native table needed the site's HTML table convention and the isolated route-validation fixture needed the newly linked storage page. These presentation/fixture corrections do not affect runtime or numerical evidence.

- Final documentation gate: initial 9/10 plus the corrected failing method and affected canonical-page test pass (10/10 distinct focused methods covered). `docs:build` and one `docs:check` pass, each validating 2,026 files/4,145 routes with zero failures. The three edited MATLAB files have no new Code Analyzer findings: both tests have zero, and the generator's 16 diagnostics exactly match main by identifier/message. Details are archived in `prepared-pipeline-20260912/final-verification`.
- Final runtime-equivalence diff is empty across `CompiledKernel` and `PortableRuntime`, excluding qualification records and the compatibility matrix's test-source fingerprint. Repository/provenance and whitespace checks pass. No catalog support, package manifest or release snapshot was changed. The new native table and old historical interface/scaling records remain distinct; no full 72-worker MATLAB/C++ refresh was run.
- Local work is ready for the final combined required CI and merge. #497/#488 are already merged/closed. #498 remains closed as a measured no-go; no vertical-pool batching rewrite was introduced.
