# Large-grid constant schedule adoption

**The compact constant-stratification schedule passes all 49 adoption gates and is enabled by default.** Native and MATLAB-loaded complete flux take about half the frozen control time at 256×256×129 and 512×512×257. The six large integration profiles take 44% of control integration time overall, with lower owned storage and lifetime peak RSS. These are Apple M4 Max results, not cross-platform performance claims.

The owner explicitly accepts the earlier 19–21% integration slowdown at 32×24×33 and declined small-grid optimization. That timing exception was recorded before this campaign. Original #358 negative and interrupted records remain unchanged in `../issue-358-adoption`; they are historical results under the original protocol, not the current adoption decision. Issue #460 remains not planned. Variable-stratification matrix adoption remains separate work under #455.

## Complete measurements

Ratios are candidate/control, so smaller is better. Parentheses contain paired 95% bootstrap intervals. Each boundary uses the same selected worker policy and equally weights its profiles.

| Boundary | Complete flux or integration time | Complete-process lifetime peak RSS |
| --- | ---: | ---: |
| Native complete flux | 0.4889 (0.4830–0.4946) | 0.4208 (0.4201–0.4217) |
| MATLAB-loaded complete flux | 0.4819 (0.4613–0.5033) | 0.6202 (0.6175–0.6226) |
| Standalone model integration | 0.4367 (0.4266–0.4460) | 0.6386 (0.6339–0.6431) |

Native and MATLAB-loaded boundaries each contain four profiles, eight alternating fresh-process pairs per profile, two excluded warmup calls and seven measured calls per process: 64 runs per boundary. Every run passes the independent MATLAB comparison; every candidate also passes the frozen C++ comparison. Neither partial samples from the previous campaign nor worker-screen measurements enter these results.

The model campaign contains six profiles, each with two excluded warmup pairs and eight measured pairs: 60 pairs / 120 runs total. Each run performs exactly four fixed RK4 steps and sixteen RHS evaluations, with dt 0.5 and final time 2. Composite cases evolve one tracer and two particles, save ordinary full-volume `u` at the endpoints and one dense `u` record at 0.75. All complete scientific output graphs, times, schema and work comparisons pass against independent MATLAB and frozen C++ controls. This is a short repeated integration measurement, not long-duration stability qualification or a large hydrostatic composite claim.

| Model profile | Integration time | Retained C++ storage | Maximum-live C++ storage | Lifetime peak RSS |
| --- | ---: | ---: | ---: | ---: |
| Hydrostatic coefficient-only, 256 | 0.4127 | 0.8698 | 0.8727 | 0.5610 |
| Hydrostatic coefficient-only, 512 | 0.4151 | 0.8589 | 0.8620 | 0.6159 |
| Nonhydrostatic coefficient-only, 256 | 0.3843 | 0.8698 | 0.8727 | 0.5574 |
| Nonhydrostatic coefficient-only, 512 | 0.4134 | 0.8589 | 0.8620 | 0.6164 |
| Nonhydrostatic composite, 256 | 0.4789 | 0.9025 | 0.9077 | 0.7758 |
| Nonhydrostatic composite, 512 | 0.5325 | 0.8940 | 0.8996 | 0.7364 |

Model complete-process lifetime ratio is 0.1285 (0.1270–0.1300), including the much faster setup. This separate metric does not replace integration timing. Overall retained and maximum-live C++ storage ratios are 0.8755 and 0.8793; the maximum owned-memory ratio across native/MATLAB-loaded flux profiles is 0.8403. Setup, execution, output, stage and storage details remain in the raw receipts.

## Protocol and provenance

`frozen-protocol.md` is the exact prospective protocol. `decision.json` records all 49 passing gates; its handoff reminder separates the measured decision from subsequent fresh-default and CI qualification. The protocol keeps numerical tolerances unchanged and declares the large workload, sample counts, uncertainty, memory gates and successful-output retention policy in advance. `postflight.json` records 258 passing source/artifact checks before default promotion.

The frozen control is `8d08ba48b554a84b9920e349e6d4c69dccd6c0dd`. Measurements reuse the original candidate executables whose production source digests match integrated `107894a120da8f2aaa545101d74190a34c38974b`; they are not described as freshly rebuilt from that merge. `provenance.json` preserves the original build identities and adds current source equivalence, the prospective protocol, harness and fixture hashes. Default promotion changes selection and reporting, without changing the measured numerical implementation.

The host is Apple M4 Max, 12 performance plus 4 efficiency cores, 128 GiB memory, FFTW 3.3.11 NEON/pthreads and MATLAB R2025b. Authoritative timing was serialized with no competing qualification/build jobs. Selected workers remain horizontal outer 12, horizontal FFTW internal 1, Type-I internal 16, coefficient 2 and pointwise 12, with the existing 4096-element serial threshold. No worker retuning or crossover investigation was performed.

## Default and compatibility handoff

CMake, the header fallback and private MATLAB build constants now select the compact schedule, with base numerical scratch `4C+6R` and prepared scalar scratch `max(4C,H)+6R`. Explicit CMake OFF or an explicit frozen schedule still selects the control. An existing CMake cache retains its cached option; a previously installed MEX keeps reporting the schedule it actually contains until rebuilt. MATLAB public APIs, numerical definitions and existing saved-file behavior are preserved.

Default-sensitive tests now check the selected schedule's storage and logical plan count. The native ownership test instruments complex FFTW column plans and sweeps the actual measured acquisition/allocation counts. The full-grid density calculus test prepares scalar resources before taking its warmed no-growth snapshot; its independent numerical oracle and publication checks are unchanged.

## Fresh-default verification

Fresh CMake builds with no explicit ON override pass 8 kernel, 14 runtime and 7 unchanged ATS source-consumer Release tests, plus 4 kernel and 4 runtime ASan/UBSan tests. The corrected density setup is rerun only in its affected target; the original failure remains in the evidence. Local macOS sanitizer runs disable unsupported LeakSanitizer; required Linux CI supplies its separate platform checks. `cpp-default-qualification.json` and its compressed companion bind the caches, flags, source and binary hashes, commands, original negative test and accepted results.

The fresh public MATLAB MEX build uses the actual private default with no compact override. It passes H/NH forward/inverse/nonlinear, estimate, metadata and lifecycle self-tests; maximum recorded error is below 3e-15. Five focused MATLAB contract methods pass. Code Analyzer has zero new findings: nine existing integration-test property warnings match the exact baseline, and the other two analyzed files have none. The `public-default` records bind the production-only export, fresh module, unchanged original provider and numerical-source equivalence; preparation-driver failures are retained separately from the successful build.

The source-bound forward-integration receipts were regenerated with a fresh actual-default runner and probe: six transform families with both reference/native providers pass all 12 cases. Strict collection and `committedReceiptsEstablishExecutedQualification` pass. New content-addressed fragments and both aggregate receipts are retained under `PortableRuntime/qualification`, with supplemental default-build/source provenance and logs in `forward-default`. The tests cover adaptive/fixed integration, continuation, stop/resume, particles, tracers and dense output.

Initial hosted CI also caught a cold scalar-preparation snapshot in the density event probe and a forbidden `.tar.gz` suffix on its text-evidence companion. The probe now explicitly prepares scalar resources before accounting for all retained kernel/service storage; the evidence container uses compressed JSON. Numerical tolerances and the source-product guard remain unchanged. Original failures and focused repair qualification are retained in `ci-repair`.

## Retained evidence

- `native-summary.json`, `matlab-summary.json`, and `model-summary.json`: exact aggregate results.
- `native-campaign.json.gz`, `matlab-loaded-campaign.json.gz`, and `model-campaign.json.gz`: all fresh campaign metadata, raw timings, comparisons, requests, reports and logs.
- `author-preparation.json.gz` and `model-preparation.json`: prospective orchestration and independent model fixture preparation.
- `decision-checks.json`: 15 evaluator checks using actual manifest/provenance schemas and synthetic timing, including rejected numerical, inventory, work, binary identity, timing and memory mutations. These are evaluator tests, not additional performance measurements.
- `model-harness-checks.json`: named-workload and verified-payload retention checks, including failure preservation.

Compressed files are UTF-8 JSON metadata bundles, not execution binaries. Each maps original local paths to exact text and SHA-256; every embedded hash was verified after compression. Read with `gzip -dc native-campaign.json.gz`.

Execution binaries, flux payloads, independent NetCDF references and the first measured output pair for each model profile remain at the local paths in the manifests. Extra successful model outputs were removed only after both full comparisons and durable hashes, as declared prospectively; all metadata and failure evidence are retained. No required local asset was missing. The original #358 scientific/lifecycle evidence remains historical coverage; fresh default and source-bound qualification is recorded separately for this promotion.
