# Free-surface construction optimization

The series continues through [issue 33: numeric prefix acceptance](issue33.md) and [issue 32: coupled convergence preparation](issue32.md). The latest report includes the refreshed profile and next-target reassessment. The report below preserves issue 31's measurements and the priorities recommended at that step.

## Issue 31: share assessment quadrature

On 14 September 2026, sharing one WKB quadrature preparation across wave and inertial comparisons reduced the matched constructor median from **29.450 to 26.323 seconds**: **3.127 seconds saved, 10.6% less elapsed time, 1.119× speedup**. This implements [InternalModes #31](https://github.com/JeffreyEarly/internal-modes/issues/31) in WVM's assessment orchestration using existing beta.5 provider APIs.

Every basis in a construction attempt shares `N2` and `zDomain`. Those inputs and the quadrature resolution determine the WKB rule; kappa does not. The rule now lives within one assessment call and is rebuilt on the next call or refinement attempt. There is no persistent cache or provider dependency change.

### Workload and revisions

- Baseline WVM: `abe98510ba3ad24276c2af2bd89c80b24209b568`, from `feature/v5.0-free-surface-qg`. Candidate: the accompanying #31 patch on `perf/v2-construction-assessment`; its production-file SHA-256 is recorded in [issue31-results.json](issue31-results.json).
- InternalModes: `8d9503e5c7c6e4b0432a5c30b42638829a8b3f37`, version `2.0.0-beta.5`, unchanged between runs.
- Apple M4 Max, 12 performance and 4 efficiency cores, 128 GiB RAM, MATLAB R2026a Update 5 (`26.1.0.3346908`), Apple Accelerate BLAS and NAG NPC LAPACK.
- Supporting dependencies: ClassAnnotations 1.2.1, Distributions 2.0.0, SplineCore 2.2.0, NetCDF 1.0.2 and chebfun 5.7.0.

```matlab
N2 = @(z) 1e-4*exp(2*z/700);
[wvt,assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[128 128 65],N2Function=N2,nEVP=104,shouldAntialias=true,shouldCheckQuadraticAliasing=false);
```

The 100 km × 100 km × 1 km domain uses automatic counts and latitude 30 degrees. There are 569 positive distinct wavenumbers plus the independent zero-wavenumber inertial page. Candidate/reference resolutions remain 104/156, with 64 candidate columns, 1,140 wave/inertial eigensolves and 38 selected wave modes on every positive page. Optional quadratic qualification is disabled.

### Matched measurements

Each version ran in its own fresh MATLAB process, with a full-workload warmup, three unprofiled trials, and one separate profiler pass. Baseline and candidate processes ran serially, with no concurrent MATLAB tests or benchmarks. The earlier milestone's 31.155-second median used an older WVM revision and a smaller warmup; it is historical context, not this comparison's denominator.

| Measurement | Before | After |
| --- | ---: | ---: |
| Unprofiled constructor trials (s) | 34.025 / 29.450 / 29.359 | 27.528 / 26.323 / 26.144 |
| Constructor median (s) | 29.450 | 26.323 |
| Wave construction/assessment median (s) | 26.244 | 22.954 |
| Separate profiler elapsed time (s) | 48.198 | 40.444 |
| Assessment quadrature preparations | 570 | 1 |
| All `configuredForEVP` calls | 588 | 19 |
| All coordinate/native-grid setups | 590 | 21 |
| All native quadrature calls | 573 | 4 |
| All dense LU constructions | 1,728 | 1,159 |

Global configuration time fell from 8.661 to 0.513 profiled seconds. The 569 removed preparations account for the matching reductions in coordinate, native-grid, quadrature and LU counts. The remaining calls serve other construction stages. Inclusive profiler times overlap and must not be added together or treated as promised unprofiled savings. These three trials establish a benefit for this workload; they do not establish scaling across other grids or quadratic qualification.

### Numerical verification and review

The saved scientific state is exactly equal with `isequaln`, excluding only the two input function handles. The complete assessment is exactly equal after replacing the three elapsed timers (`assessmentSeconds`, `waveConstructionSeconds`, `constructionSeconds`) with NaNs. All scientific measurements, quadrature nodes/weights, labels, statuses, mode counts, tolerances and cost counters remain compared.

All **24 tests passed** in `TestPerKappaWaveAssessment`, `TestFreeSurfaceBulkConstruction`, `TestFreeSurfaceVariableWaveCounts`, `TestAutomaticFreeSurfaceModeSelection` and `TestFreeSurfaceLinearModePolicy`. These include constant/exponential stratification, independently solved bulk representations and physical fields, strict count rejection, changed domains/reference resolutions, mixed active/zero pages, no reference and inertial-only assessment. The new oracle independently reconstructs each page's quadrature using the same candidate/reference bases.

Focused tests used immutable dependency snapshots from OceanKit `1873071fe2dfc2678490df1b0252e5071e9d9715`, including InternalModes beta.5. The ordinary local OceanKit checkout lacked that snapshot, so verification used an isolated checkout of the CI pin. MATLAB Code Analyzer reported zero blocking findings across all four changed MATLAB files; one nonblocking array-growth advisory concerns the benchmark's small package-path setup loop, outside measured construction. `buildtool docs:check` passed once with ClassDocumentation 1.3.2: 2,654 files, 5,415 routes, zero validation failures and zero generated differences. Whitespace and scope checks confirmed unchanged package metadata, released snapshots and generated documentation. GPT-6 Astra with extra-high reasoning reviewed production code, regressions and study helpers; no findings remain. A timer-exclusion omission in the comparison helper was corrected before the successful comparison.

### Next target after issue 31

Recommend **[InternalModes #33](https://github.com/JeffreyEarly/internal-modes/issues/33) before [#32](https://github.com/JeffreyEarly/internal-modes/issues/32)**, then [#34](https://github.com/JeffreyEarly/internal-modes/issues/34) and [#35](https://github.com/JeffreyEarly/internal-modes/issues/35). `acceptedPrefix` still performs 570 calls taking 7.235 profiled seconds, with 6.630 seconds at its repeated table/string scan. That is close to the 7.903 seconds in 1,140 `prepare` calls, while numeric acceptance is a smaller implementation with fewer numerical changes than batching evaluation/derivatives/normalization. This ranking is an engineering judgment, not a speedup estimate. Its apparent profiler increase from 5.632 seconds is not evidence of an unprofiled regression in unchanged acceptance code.

The Gram-prefix loop remains about 1.699 profiled seconds. Native parallel construction stays later because of its larger integration and numerical-validation scope. **After each optimization, remeasure construction, reprofile, and update the remaining priorities before starting the next target.** This patch implements only #31.

### Reproduction

Place the frozen baseline and candidate WVM worktrees beside the pinned InternalModes authoring checkout and supporting dependency roots listed above. Run each command in a fresh MATLAB process outside the local macOS sandbox. Substitute absolute paths for `WORKSPACE`, `CANDIDATE` and `OUTPUT`:

```sh
matlab -batch "addpath('CANDIDATE/tools/construction-optimization-study'); runConstructionOptimizationStudy('WORKSPACE/wvm-v5-construction-baseline','WORKSPACE/internal-modes','OUTPUT/baseline');"
matlab -batch "addpath('CANDIDATE/tools/construction-optimization-study'); runConstructionOptimizationStudy('CANDIDATE','WORKSPACE/internal-modes','OUTPUT/candidate');"
matlab -batch "addpath('CANDIDATE/tools/construction-optimization-study','WORKSPACE/OceanKit/tools/profiling'); compareConstructionOptimizationStudy('OUTPUT/baseline','OUTPUT/candidate');"
```

The harness checks resolved checkout paths, writes raw timing JSON, complete scientific/assessment MAT files, and a separate `profileCodeHotspots` analysis. The comparison preserves exact counters and reports and uses `compareProfileHotspots` after normalizing only the baseline worktree paths. Function changes are primary evidence; moved source lines are secondary. Large MAT/profile artifacts stay outside the repository; the essential measurements and verification results are embedded here and in the linked JSON.
