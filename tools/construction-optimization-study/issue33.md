# Issue 33: numeric prefix acceptance

On 14 September 2026, replacing repeated measurement-table scans with numeric summaries reduced the matched free-surface constructor median from **26.480 to 21.903 seconds**: **4.577 seconds saved, 17.3% less elapsed time, 1.209× speedup**. This is the incremental improvement after [issue 31](README.md), implemented on the same `perf/v2-construction-assessment` branch and [WVM PR #528](https://github.com/JeffreyEarly/wave-vortex-model/pull/528).

## Implementation and scientific policy

[InternalModes #33](https://github.com/JeffreyEarly/internal-modes/issues/33) is implemented entirely in WVM. `summarizeModeConvergence` reads the relevant equivalent-depth/H1 rows, label associations, statuses and values once per report. It groups evidence by scientific label, computes numeric pass flags and the leading accepted count, and retains cumulative maximum errors for subsequent selected prefixes.

The summary is temporary data passed from assessment through construction into count selection. Both initial and quadratic-reduced selected-error reports use the same prefix values. Existing public reports, table schemas and ordering remain unchanged; no summaries enter scientific state or persistence. No provider API, package dependency, scientific tolerance or model-specific policy moves into InternalModes.

Missing or ambiguous labels retain the provider's inconclusive status. Every requested group contributes to completeness, including modes after the first failure. Passing uses the original `<= tolerance` comparisons; numeric maxima independently preserve MATLAB's handling of all-NaN prefixes and subsequent finite evidence. Zero wave pages remain unrequested, inertial counts remain independent, and explicit counts retain strict rejection.

## Workload and revisions

- Baseline WVM: `95b5bd3630287f6c8022729e37ce238ae096ed18`, the completed #31 implementation. Candidate: the accompanying #33 patch; [issue33-results.json](issue33-results.json) records hashes of its four production files.
- InternalModes: unchanged `8d9503e5c7c6e4b0432a5c30b42638829a8b3f37`, version `2.0.0-beta.5`.
- Apple M4 Max, 12 performance and 4 efficiency cores, 128 GiB RAM, MATLAB R2026a Update 5 (`26.1.0.3346908`), Apple Accelerate BLAS and NAG NPC LAPACK.
- Dependencies: ClassAnnotations 1.2.1, Distributions 2.0.0, SplineCore 2.2.0, NetCDF 1.0.2 and chebfun 5.7.0.

```matlab
N2 = @(z) 1e-4*exp(2*z/700);
[wvt,assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[128 128 65],N2Function=N2,nEVP=104,shouldAntialias=true,shouldCheckQuadraticAliasing=false);
```

The 100 km × 100 km × 1 km domain uses automatic family counts and latitude 30 degrees. Both versions have 569 positive distinct wavenumbers, candidate/reference resolutions 104/156, 64 candidate columns, 1,140 wave/inertial eigensolves, and 38 selected wave modes on every positive page. Optional quadratic qualification is disabled in the timed workload; smaller quadratic-reduction regressions run separately.

## Matched measurements

Baseline and candidate ran serially in separate fresh MATLAB processes. Each performed a full-workload warmup, three unprofiled trials, and one separate profiler pass. No other MATLAB benchmark or test ran concurrently. The measurement harness is unchanged from #31.

| Measurement | After #31 / before #33 | After #33 |
| --- | ---: | ---: |
| Unprofiled constructor trials (s) | 27.576 / 26.480 / 26.344 | 23.594 / 21.903 / 21.178 |
| Constructor median (s) | 26.480 | 21.903 |
| Wave construction/assessment median (s) | 23.123 | 18.095 |
| Separate profiler pass (s) | 41.380 | 33.206 |
| Old scalar prefix acceptance | 570 calls / 7.355 profiled s | Removed |
| New numeric summary | Absent | 570 calls / 0.325 profiled s |
| Selected-error table extraction | 1,140 calls / 0.360 profiled s | Removed |
| Both selected-convergence passes | 0.403 profiled s | 0.031 profiled s |
| Global `ismember` calls | 86,593 | 48,973 |

The old acceptance loop performed 36,480 full-table quantity/label scans. The new path groups 570 reports once each and reuses those numeric results for selected-error reporting. There are 37,620 fewer global `ismember` calls. Global configuration remains at 19 calls, so #31's quadrature reuse is preserved. The global generalized-solve count remains 1,144, including the four non-wave solves outside the 1,140 wave/inertial counter.

Profiler rows are inclusive diagnostic evidence. They overlap and must not be summed into predicted constructor savings. The measured 17.3% reduction uses the unprofiled medians above; it does not use the milestone's historical 31.155-second baseline or add percentages from successive optimizations. Three trials establish this workload's measured benefit, not universal scaling across grids or nonlinear qualification.

## Verification and review

The full saved scientific state is exactly equal with `isequaln`, excluding only input function handles. All assessment reports are exactly equal after excluding the three named elapsed timers (`assessmentSeconds`, `waveConstructionSeconds`, `constructionSeconds`). Measurements, coverage, nodes/weights, identity, labels, statuses, selected counts, tolerances, prefixes and cost counters remain compared.

The six focused suites passed **29/29 tests**: `TestWaveModeConvergenceSummary`, `TestPerKappaWaveAssessment`, `TestFreeSurfaceBulkConstruction`, `TestFreeSurfaceVariableWaveCounts`, `TestAutomaticFreeSurfaceModeSelection`, and `TestFreeSurfaceLinearModePolicy`. After simplifying the prefix maximum with `cummax(...,"omitnan")` and completing the integration assertions, the affected **8/8 methods passed again** on the final code. Tests used immutable beta.5 snapshots from OceanKit `1873071fe2dfc2678490df1b0252e5071e9d9715`.

The new tests compare provider-produced reports with a frozen copy of the previous scalar table policy. They cover reordered candidate/reference labels and measurement rows; missing, duplicate and extra reference labels; duplicate candidates; a late inconclusive mode after an earlier failure; non-measured evidence; exact tolerance equality; near-zero, zero, Inf and NaN scalars; all-NaN then finite prefix maxima; and zero requested count. Integration assertions cover nonuniform/zero wave pages, independent inertial selected errors, and the known quadratic-reduced `[10;19;19;10]` wave map. Existing tests retain strict-count and underresolution rejection and physical-field comparisons.

GPT-6 Astra with extra-high reasoning reviewed production code, regressions and integration. No findings remain. The review led to the simpler cumulative-maximum calculation and corrected a test expectation for a late unmatched mode; that mode leaves the prior finite maximum unchanged while completeness becomes false.

MATLAB Code Analyzer ran once on the seven changed MATLAB files: zero active or blocking findings, with two existing performance suppressions in unchanged quadratic-selection code. `buildtool docs:check` passed once with ClassDocumentation 1.3.2: 2,654 files, 5,415 routes, zero validation failures and zero generated differences. Whitespace and scope checks confirmed unchanged package metadata, released snapshots and generated documentation. The successful scientific comparison was not repeated when its temporary launcher's path reset required starting the remaining static/documentation checks in a separate process.

## Reassessed next target

Recommend [InternalModes #32](https://github.com/JeffreyEarly/internal-modes/issues/32), batching mode values, derivatives and normalization, next. Its 1,140 `prepare` calls still take **7.627 inclusive profiled seconds** after #33, while the new numeric acceptance summary takes 0.325 seconds. This is remaining hotspot evidence, not a promised saving.

Keep [#34](https://github.com/JeffreyEarly/internal-modes/issues/34) after #32: the Gram-prefix loop remains about **1.673 profiled seconds**. Keep [#35](https://github.com/JeffreyEarly/internal-modes/issues/35), native parallel construction, later because of its broader integration and numerical-validation scope. The generalized-solve helper now has 7.321 profiled self seconds; its 11.498-second inclusive total also contains filtering and basis work, so it is not an isolated QZ timing. Reassess that opportunity after preparation changes.

**After each optimization, remeasure construction, reprofile, and update the remaining priorities before starting the next target.** The current remaining order is #32 → #34 → #35. This change implements only #33 on top of #31.

## Reproduction

Use the unchanged [`runConstructionOptimizationStudy`](runConstructionOptimizationStudy.m) and [`compareConstructionOptimizationStudy`](compareConstructionOptimizationStudy.m) helpers. Freeze a baseline WVM worktree at `95b5bd36`, configure the pinned InternalModes authoring checkout and supporting roots as in the [#31 setup](README.md#reproduction), and run each version in a fresh MATLAB process outside the local macOS sandbox:

```sh
matlab -batch "addpath('CANDIDATE/tools/construction-optimization-study'); runConstructionOptimizationStudy('WORKSPACE/wvm-v5-construction-issue33-baseline','WORKSPACE/internal-modes','OUTPUT/baseline');"
matlab -batch "addpath('CANDIDATE/tools/construction-optimization-study'); runConstructionOptimizationStudy('CANDIDATE','WORKSPACE/internal-modes','OUTPUT/candidate');"
matlab -batch "addpath('CANDIDATE/tools/construction-optimization-study','WORKSPACE/OceanKit/tools/profiling'); compareConstructionOptimizationStudy('OUTPUT/baseline','OUTPUT/candidate');"
```

Substitute absolute paths for the placeholders. The comparison normalizes only worktree paths for `compareProfileHotspots`; raw profiles remain intact. Large scientific/profile MAT files remain outside the repository. The essential timings, function counts, source hashes and verification results are embedded in this report and its JSON.
