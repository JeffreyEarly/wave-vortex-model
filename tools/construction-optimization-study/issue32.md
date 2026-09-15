# Issue 32: coupled convergence preparation

On 14 September 2026, batching candidate/reference mode preparation reduced the matched free-surface constructor median from **21.886 to 19.944 seconds**: **1.942 seconds saved, 8.9% less elapsed time, 1.097× speedup**. This is the incremental change after [#31](README.md) and [#33](issue33.md), on the same branch and [WVM PR #528](https://github.com/JeffreyEarly/wave-vortex-model/pull/528).

## Implementation

[InternalModes #32](https://github.com/JeffreyEarly/internal-modes/issues/32) is implemented in WVM's assessment orchestration. `prepareWaveModeConvergenceBatches` prepares three operators per compatible solver and polynomial count through the existing beta.5 solver methods: values, first physical derivative and second physical derivative. Each selected stored basis computes normalization once. Batches of at most 16 requested pages share matrix applications, with separate column slices for heterogeneous mode counts.

The raw first derivative supplies both the normalized derivative of G and F recovered through the provider's `FfromGz` callback, preserving recovery before normalization. The existing second-derivative calculation supplies the derivative of F. The helper preserves each basis's identity, scientific labels, equivalent depths and provenance. The convergence assessor consumes each candidate/reference batch and retains the existing detailed reports; it does not retain sampled arrays for every wavenumber.

Reuse is call-local, with solver equality and polynomial-count checks. Changed resolutions, domains or sample grids cannot reuse stale operators across calls. The fast path is restricted to the built-in spectral WKB G-form wave basis; incompatible solvers and custom basis subclasses retain scalar evaluation. Exact built-in bases can still share normalization on the fallback path, while subclasses retain their overridden F/G dispatch.

InternalModes remains unchanged at beta.5. Its existing public numerical methods provide the operators and physical recovery; WVM owns the paired consumer and mode-count policy. No provider API, package dependency, scientific tolerance, released snapshot or model policy changes.

## Workload and revisions

- Baseline WVM: `c7ed4194c474cea9273bfe7a07b56a2e3b568173`, containing #31 and #33. Candidate: this accompanying patch; [issue32-results.json](issue32-results.json) records production source hashes.
- InternalModes: `8d9503e5c7c6e4b0432a5c30b42638829a8b3f37`, version `2.0.0-beta.5`.
- Apple M4 Max, 12 performance and 4 efficiency cores, 128 GiB RAM, MATLAB R2026a Update 5 (`26.1.0.3346908`), Apple Accelerate BLAS and NAG NPC LAPACK.
- Supporting packages: ClassAnnotations 1.2.1, Distributions 2.0.0, SplineCore 2.2.0, NetCDF 1.0.2 and chebfun 5.7.0.

```matlab
N2 = @(z) 1e-4*exp(2*z/700);
[wvt,assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[128 128 65],N2Function=N2,nEVP=104,shouldAntialias=true,shouldCheckQuadraticAliasing=false);
```

The domain is 100 km × 100 km × 1 km, with automatic family counts and default latitude 30 degrees. Both versions use 569 positive wavenumbers plus zero, candidate/reference resolutions 104/156, 64 candidate columns per page, 313 assessment quadrature samples and 1,140 wave/inertial solves. Every positive page retains 38 wave modes. Optional quadratic qualification is disabled in timing runs and covered separately by focused tests.

## Measurements

The unchanged construction harness ran baseline and candidate serially in fresh MATLAB processes, each with one full-workload warmup, three unprofiled trials and a separate profiler pass. No other MATLAB task ran concurrently.

| Measurement | Before #32 | After #32 |
| --- | ---: | ---: |
| Full constructor trials (s) | 21.886 / 22.416 / 20.143 | 20.419 / 19.411 / 19.944 |
| Full constructor median (s) | 21.886 | 19.944 |
| Wave construction/assessment median (s) | 18.244 | 16.156 |
| Separate full profiler pass (s) | 32.605 | 28.437 |
| Isolated preparation/evaluation trials (s) | 3.438 / 3.435 / 3.362 | 0.766 / 0.753 / 0.773 |
| Isolated preparation/evaluation median (s) | 3.435 | 0.766 |
| Global normalization calls / profiled seconds | 4,573 / 5.010 | 2,293 / 2.567 |
| Global Chebyshev evaluation-matrix constructions | 13,791 | 6,957 |

The isolated measurement uses already solved collections and common quadrature, warming both paths before three alternating scalar/batched trials. It includes normalization, value/derivative evaluation, physical recovery, struct assembly and the same checksum consumption. It excludes eigensolves and convergence measurements. This combined preparation/evaluation operation is **4.49× faster**, saving **2.669 seconds** in isolation. The complete constructor's measured saving is **1.942 seconds**; isolated and profiled components are not additive partitions of constructor time.

The separate profile resolves the phases: old scalar preparation took **7.807 inclusive seconds in 1,140 calls**; the new setup/normalization phase took **2.177 seconds in two plans**, and batch evaluation/recovery/struct assembly took **0.411 seconds in 72 chunks**. The outer helper's **3.699 seconds includes 1.103 seconds in its convergence-assessment consumer**, so that outer total is not directly comparable to scalar preparation alone. There are two value operators and four derivative operators for convergence preparation, versus repeated scalar construction. Global configuration remains at 19 calls, and numeric acceptance remains at 570 summaries, preserving #31/#33.

The 31.155-second historical milestone baseline used an earlier revision and warmup protocol; it is context, not this step's matched baseline. Inclusive profiler times overlap and must not be summed into promised savings. Three trials demonstrate this workload's benefit, not universal scaling or nonlinear qualification performance.

## Bounded allocation

The default batch size is 16 pages. For 313 samples and 64 columns, an analytical model of the main live arrays is **37.87 MiB**: both resolutions' three operators, up to three sets of four-field page outputs during MATLAB assignment evaluation, up to two sampled raw batches, one native coefficient batch and all normalization factors. The estimate deliberately accounts for the previous chunk remaining alive while the next assignment's right-hand side executes.

This is **neither measured peak memory nor process RSS**. Existing bases/native modes, convergence reports, object/cell metadata, allocator overhead, BLAS workspace and short-lived elementwise temporaries are excluded. The sampled-field contribution scales with the configured batch size, not all 570 pages; factor storage scales with the selected bases. The actual constructor has one compatible solver group per resolution. The estimate and individual byte counts are recorded in the JSON.

## Verification

The full saved scientific state is exactly equal under the existing `isequaln` comparison, excluding input function handles. Assessment reports are exactly equal after removing only the three named elapsed timers. Selected counts, labels, normalization, physical arrays, tolerance decisions, measurements, prefixes, report schemas and cost counters remain compared. No comparator or scientific tolerance was relaxed.

The seven focused suites passed **34/34 tests**, followed by the added custom-subclass fallback regression (**1/1**), for **35 passing tests**. The six new parameter-expanded preparation tests cover constant, exponential and sharp positive stratification; k = 0 inertial modes; very long external waves at k = 1e-9; heterogeneous counts; independent reordered/repeated candidate/reference pages; custom normalization; a two-page callback bound; changed resolution/domain/sample grids; finite-difference fallback; and overridden F/G subclass methods. Each uses an independent copy of the previous scalar preparation. Existing integration suites cover zero wave pages, independent inertial counts, strict count rejection, underresolution and quadratic-reduced selection.

Tests and the isolated preparation benchmark resolved immutable beta.5 packages from OceanKit `1873071fe2dfc2678490df1b0252e5071e9d9715`; full-constructor timings resolved the pinned authoring provider. GPT-6 Astra with extra-high reasoning reviewed simplicity and correctness. Its fallback-dispatch concern was fixed and covered by the dedicated subclass regression; no findings remain.

After timing, exact-class guards were expressed using the provider's `string(class(...))` equality idiom, preserving subclass exclusion while satisfying Code Analyzer. All six preparation regressions passed again on the final spelling; no numerical formulas changed. Analyzer verification initially identified an unused suppression and generic recommendations to use `isa`, which would admit subclasses and violate the fallback contract. The final five changed MATLAB files have zero active, suppressed or blocking findings.

`buildtool docs:check` passed once with ClassDocumentation 1.3.2: 2,654 files, 5,415 routes, zero validation failures and zero generated differences. Whitespace, scope and manifest checks confirm that package metadata, released snapshots and generated documentation remain unchanged.

## Reassessment

The eigensolve is now the largest individual hotspot: the `eig(...)` line takes **7.311 profiled seconds**. Its enclosing generalized-solve helper takes 12.319 seconds, including orientation, filtering and other work; these are different scopes.

A newly exposed, narrower candidate deserves investigation before changing the Gram-prefix algorithm: `IMInternalModesBasis.orientModeSigns` takes **2.988 inclusive profiled seconds**, including a grid-values-to-coefficients LU solve in `differentiateGridValues`. That LU line takes **2.104 seconds across all 1,153 differentiation calls**, including callers outside the 1,144 orientation calls. For the built-in spectral G formulation, the native coefficients already exist. A direct coefficient derivative could remove this round trip while retaining the orientation policy. This is a code-supported opportunity, not a measured optimization or a promise to save 2.104 seconds. The unchanged routine varied between 2.117 and 2.988 seconds across these profiles, so isolate and remeasure it first. Custom/F-form/fallback behavior and decisions near orientation thresholds require explicit regressions.

The existing Gram-prefix target [#34](https://github.com/JeffreyEarly/internal-modes/issues/34) remains **1.628 profiled seconds**, with 36,480 growing-prefix norms. Give it a bounded investigation and defer if preserving spectral diagnostics and tolerance-boundary decisions requires disproportionate numerical complexity. Toolbox-free parallel construction [#35](https://github.com/JeffreyEarly/internal-modes/issues/35) now has a larger relative opportunity, but its earlier 7.15 → 1.77-second native probe is historical, excludes integration, and must be refreshed before projecting current constructor gains.

The zero-APV boundary-response solve also takes **3.701 inclusive profiled seconds**, including 2.178 seconds in boundary linear solves. Record this as a further investigation candidate; the matrices vary with wavenumber, so reuse cannot be assumed. These rows overlap other profile totals and do not form a savings budget.

**After each optimization, remeasure construction, reprofile, and update the remaining priorities before starting the next target.** This patch implements only #32 on top of #31/#33; no later numerical optimization is started.

## Reproduction

Freeze a baseline worktree at `c7ed4194`, use the pinned dependencies and the [existing setup](README.md#reproduction), then substitute absolute paths in:

```sh
matlab -batch "addpath('CANDIDATE/tools/construction-optimization-study'); runConstructionOptimizationStudy('WORKSPACE/wvm-v5-construction-issue32-baseline','WORKSPACE/internal-modes','OUTPUT/baseline');"
matlab -batch "addpath('CANDIDATE/tools/construction-optimization-study'); runConstructionOptimizationStudy('CANDIDATE','WORKSPACE/internal-modes','OUTPUT/candidate');"
matlab -batch "addpath('CANDIDATE/tools/construction-optimization-study','WORKSPACE/OceanKit/tools/profiling'); compareConstructionOptimizationStudy('OUTPUT/baseline','OUTPUT/candidate');"
```

For isolated preparation, configure the same candidate and beta.5 package paths, then call:

```matlab
runWaveModePreparationStudy('OUTPUT/baseline/scientific-result.mat','OUTPUT/preparation-timing.json');
```

Run every local `matlab -batch` outside the macOS sandbox. The comparison helper normalizes worktree paths only for profile matching; raw profiles are unchanged. Large MAT files remain outside the repository. This report and its JSON embed the essential evidence without requiring local scratch files.
