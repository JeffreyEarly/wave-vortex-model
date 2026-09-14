# Issue 36: skip unused orientation derivatives

[InternalModes #36](https://github.com/JeffreyEarly/internal-modes/issues/36) is implemented in [InternalModes PR #37](https://github.com/JeffreyEarly/internal-modes/pull/37) and released as [2.0.0-beta.6](https://github.com/JeffreyEarly/internal-modes/releases/tag/v2.0.0-beta.6). The provider skips sampled differentiation when every surface G value already determines its mode's sign. WVM adopts the released package; model-specific selection remains in WVM.

## Implementation and correctness

The fast path requires the exact built-in `IMInternalModesBasis`, exact `IMSolverSpectral`, G formulation and native coefficient row count. Any derivative-dependent column retains the original derivative calculation for the entire basis, with the same matrix and right-hand-side width. Custom basis/solver overrides, F-form recovery and over-resolved coefficients retain their original paths. The existing relative threshold remains exactly `1e-10`; the policy and the guard share that constant.

A direct coefficient derivative is mathematically equivalent but changed floating-point decisions at the derivative cutoff. That proposal was rejected. Tests preserve both a single-column reproducer and mixed columns where changing the solve width could change accumulation. An over-resolved Chebyshev example also verifies the old aliased-grid derivative fallback.

## Pinned workload

- WVM baseline and measured constructor source: `d13099a68fd02604224f3bff93488fb95b6c8f1c`, containing #31/#33/#32.
- InternalModes baseline: beta.5, `8d9503e5c7c6e4b0432a5c30b42638829a8b3f37`; implementation: `dfd7d67155d204046426e16b493758d4731001eb`; release preparation: `3c9a2ba20937f15071db6b1c58be78a69d5c15ec`; released merge/tag: `370162ddf71781689b560163bb3e3d2751d80c28`.
- [OceanKit export PR #18](https://github.com/JeffreyEarly/OceanKit/pull/18), immutable merge `dc87744d8cb32d5aa1542daf0a01c8ff9fa10f31`.
- Apple M4 Max (12 performance + 4 efficiency cores), 128 GiB RAM, MATLAB R2026a Update 5 (`26.1.0.3346908`), Apple Accelerate BLAS/NAG NPC LAPACK.
- ClassAnnotations 1.2.1, Distributions 2.0.0, SplineCore 2.2.0, NetCDF 1.0.2 and chebfun 5.7.0 for constructor timing. Provider export tests use SplineCore 2.0.0 at its declared floor.

```matlab
N2 = @(z) 1e-4*exp(2*z/700);
[wvt,assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[128 128 65],N2Function=N2,nEVP=104,shouldAntialias=true,shouldCheckQuadraticAliasing=false);
```

This uses 569 positive wavenumbers plus zero, candidate/reference resolutions 104/156, 64 candidate columns, 313 assessment nodes and 1,140 wave/inertial solves. Every positive page retains 38 modes. Optional quadratic qualification is disabled for timing and exercised by focused tests.

## Measurements and uncertainty

Each constructor process performs a complete warmup, three unprofiled trials and a separate profile. MATLAB jobs ran serially. [Raw summaries and source hashes](issue36-results.json) retain all final-implementation runs, including the inconsistent default-thread results.

| Measurement | Beta.5 | Beta.6 implementation |
| --- | ---: | ---: |
| Orientation-only trials (s) | 0.493026 / 0.534893 / 0.511538 | 0.396501 / 0.396218 / 0.400362 |
| Orientation-only median (s) | 0.511538 | 0.396501 |
| Controlled constructor trials (s) | 17.112316 / 16.582694 / 16.282122 | 16.409963 / 15.550675 / 15.228888 |
| Controlled constructor median (s) | 16.582694 | 15.550675 |
| Controlled wave-stage median (s) | 14.295518 | 13.417522 |
| Separate controlled profile (s) | 25.350037 | 23.120884 |
| Profiled orientation calls / seconds | 1,144 / 1.081417 | 1,144 / 0.711012 |
| Profiled sampled differentiation calls / seconds | 1,153 / 0.175621 | 13 / 0.005192 |

**Controlled** means `maxNumCompThreads(1)` was set at process start. The full median is 6.2% lower in this comparison; the complete 1.032-second difference is not attributed to this narrow change, and it is not a claim about default-thread throughput. The orientation-only result is 22.5% lower (0.115 seconds saved). Its harness applies orientation again to 1,140 already-solved, already-oriented bases, including raw evaluations, sign application, metadata and checksum; it excludes eigensolves and construction. Matching checksums are a repeatability check; independent legacy-oracle tests and full scientific-state comparisons establish parity.

The default was 16 computation threads. Its initial baseline median was 20.201 seconds, candidate 29.365 seconds, and unchanged baseline recheck 34.483 seconds. Profiles showed large variation in unchanged DenseLU work, particularly zero-APV boundary solves outside the changed path. Those runs establish **no reliable default-thread constructor speedup**. The cause of the variation is not established. Fixed-thread measurements are additional controlled evidence, not replacements hidden in the default series.

Profiler times are inclusive and overlap; they cannot be added to the microbenchmark saving or summed into a forecast. The historical milestone's 31.155-second median and 46.998-second profile are different measurements. Three trials per process do not establish universal scaling or tight statistical uncertainty.

The change removes a full sampled derivative result on each eligible basis (52 KiB at 104×64 doubles, 78 KiB at 156×64), plus associated coefficient recovery workspaces. It adds only per-column scales and predicates. These are array-size observations, not measured peak memory or RSS; no cache or persistent state is introduced.

## Release and verification

The actual provider export passed all 34 focused tests. Its 12 orientation tests cover constant/exponential/sharp profiles, z/WKB/density coordinates, free/rigid boundaries, long external/zero-wavenumber/near-inertial waves, flipped/scaled coefficients, surface and derivative thresholds, unresolved references, F-form barotropic fallback, overrides and over-resolved coefficients. GPT-6 Astra extra-high independently reviewed the implementation and release claims; no findings remain.

The saved numerical scientific state is exactly equal between before/after runs, excluding the two input function handles. Complete assessments match exactly after removing only `assessmentSeconds`, `waveConstructionSeconds` and `constructionSeconds`. All scientific tolerances, labels, counts, physical arrays, normalization, measurements, prefixes and report semantics remain compared. This holds for both the default-thread and controlled comparisons.

Code Analyzer found zero active or blocking diagnostics in the six changed provider MATLAB files; two existing growth suppressions remain. The release version was assigned through `matlab.mpm.Package`; the pinned central OceanKit exporter produced 237 byte-identical payload files, excluding authoring directories and untracked macOS metadata. Documentation was built using ClassDocumentation 1.3.2. Unrelated generator formatting churn was discarded; the generated beta.6 version history was retained. No existing released snapshot was edited.

WVM adoption also passes all nine release-verification tests. Its five changed MATLAB files have zero blocking diagnostics and one pre-existing informational array-growth advisory in benchmark path setup. `docs:build` and `docs:check` pass with 2,654 files, 5,415 routes and zero validation failures; only the intended version-history change is retained.

## Reassessment and reproduction

The refreshed controlled profile still places the generalized eigensolve first and the Gram-prefix loop near 1.6 seconds. Proceed to the bounded investigation in [#34](https://github.com/JeffreyEarly/internal-modes/issues/34): preserve every spectral-norm prefix diagnostic and tolerance decision, retaining a worthwhile improvement or recording an evidence-based deferral. [#35](https://github.com/JeffreyEarly/internal-modes/issues/35) remains outside this goal. Runtime/threading variation must be controlled before projecting a native parallel gain.

**After each optimization, remeasure construction, reprofile, and update remaining priorities before starting the next target.** Tracking these tasks in InternalModes does not introduce a WVM dependency or move selection policy into the provider.

Use the [existing setup](README.md#reproduction), a baseline WVM worktree at `d13099a6`, and the two pinned provider revisions. Run the construction harness serially in fresh MATLAB processes, adding `maxNumCompThreads(1);` before its invocation to reproduce the controlled pair. Use `compareConstructionOptimizationStudy` for exact numerical/report parity and a separate profile comparison. The harness now permits a provider snapshot nested beneath OceanKit while retaining workspace-relative supporting dependencies. Run local `matlab -batch` outside the macOS sandbox.

For isolated orientation, configure the desired provider and released dependency paths, then run the provider's `tools/runModeOrientationStudy.m` against the saved baseline `scientific-result.mat`. Large MAT files remain outside the repository; this report and JSON contain the essential evidence.
