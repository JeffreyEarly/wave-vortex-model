# Issue 34: Gram-prefix optimization deferred

[InternalModes #34](https://github.com/JeffreyEarly/internal-modes/issues/34) concludes with a documented deferral. Preparing the Gram error matrix once per page preserves the complete numerical result, but saves only about **9 milliseconds in isolation** and produces a **20-millisecond constructor median difference**. Neither establishes a worthwhile constructor improvement. The original production loop is retained.

## Bounded experiment

The candidate replaced repeated `norm(gram(1:n,1:n)-eye(n),2)` calls with one `gram=gram-eye(count)` followed by the same leading-block `norm(...,2)` calls. Both positive-wave and inertial loops were changed. Every norm still receives the same matrix entries; the candidate neither assumes exact symmetry nor substitutes another norm or omits diagnostics.

The [candidate patch](issue34-candidate.patch) and its source hash in [the results JSON](issue34-results.json) reproduce the tested change. The patch is an experimental artifact and is not applied to production. The isolated harness retains independent copies of both loops.

More involved alternatives were screened without implementation or performance claims. Symmetrizing a rounded weighted Gram changes the defined diagnostic; exact symmetry cannot simply be assumed. Grouped SVD or incremental singular-value updates would need additional numerical validation, bounded grouping/workspaces and reliable behavior at tolerance boundaries. The evidence does not justify expanding this bounded task into that numerical work while the eigensolve remains the larger target. This is a prioritization decision, not a claim that better prefix algorithms are impossible.

## Revisions and reproduction

- WVM before this experiment: `6925d125`, containing #31, #33, #32 and beta.6 adoption. The additional evidence commit `1983f3d08712ff00011e4331038be5350d1369b6` changes no numerical production code.
- Provider: released InternalModes **2.0.0-beta.6**, tag/merge `370162ddf71781689b560163bb3e3d2751d80c28`, loaded from the exported OceanKit snapshot at `dc87744d8cb32d5aa1542daf0a01c8ff9fa10f31`.
- Apple M4 Max, 12 performance + 4 efficiency cores, 128 GiB RAM, MATLAB R2026a Update 5 (`26.1.0.3346908`), Apple Accelerate BLAS and NAG NPC LAPACK.
- ClassAnnotations 1.2.1, Distributions 2.0.0, SplineCore 2.2.0, NetCDF 1.0.2 and chebfun 5.7.0.
- Every timing process explicitly sets `maxNumCompThreads(1)`. These are controlled measurements, not default-thread throughput claims; [#36](issue36.md) documents the substantial default-thread runtime variation.

```matlab
maxNumCompThreads(1);
N2 = @(z) 1e-4*exp(2*z/700);
[wvt,assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[128 128 65],N2Function=N2,nEVP=104,shouldAntialias=true,shouldCheckQuadraticAliasing=false);
```

The pinned workload has 569 positive wavenumbers plus zero, resolutions 104/156, 64 candidate columns, 313 assessment samples and 1,140 candidate/reference wave/inertial solves. Automatic selection retains 38 modes on every positive page. Optional quadratic qualification is disabled for timing.

Use `runConstructionOptimizationStudy` for each revision in fresh serial MATLAB processes: full-workload warmup, three unprofiled trials and a separate profile. Use `compareConstructionOptimizationStudy` to compare the full numerical state and reports. Reproduce the isolated study after configuring the candidate tools path:

```matlab
maxNumCompThreads(1);
runGramPrefixStudy('OUTPUT/baseline/scientific-result.mat','OUTPUT/gram-prefix-study.json',wvmRoot="WVM_ROOT",internalModesRoot="OCEANKIT_ROOT/InternalModes-2.0.0-beta.6");
```

Run local `matlab -batch` outside the macOS sandbox. The [existing setup](README.md#reproduction) describes the surrounding workspace. No Optimization or Parallel Computing Toolbox is used.

## Measurements

| Measurement | Original loop | One identity subtraction per page |
| --- | ---: | ---: |
| Full constructor trials (s) | 16.341917 / 15.450600 / 15.203109 | 16.371152 / 15.430472 / 15.182556 |
| Full constructor median (s) | 15.450600 | 15.430472 |
| Wave stage median (s) | 13.355287 | 13.303457 |
| Separate full profiler pass (s) | 23.173685 | 23.234000 |
| Positive prefix-loop profiled line (s) | 1.574019 | 1.561836 |
| Isolated full prefix workload median (s) | 1.566708 | 1.557402 |

The constructor median difference is **0.020129 seconds (0.13%)**. The full profile is slightly slower with the candidate. The isolated difference is **0.009306 seconds (0.59%)**. Five alternating isolated trials were:

- Original: 1.566708 / 1.574423 / 1.572274 / 1.565000 / 1.563557 seconds.
- Candidate: 1.551160 / 1.557614 / 1.558615 / 1.557402 / 1.546852 seconds.

These differences are too small to justify a constructor speedup claim. Inclusive profile times overlap and are not additive savings. In particular, eliminating identity construction cannot save the whole prefix-loop cost: all 36,480 spectral norms remain.

The isolated measurement includes Gram products, input validation, identity subtraction, prefix slicing, norms, threshold decisions and result allocation. MAT loading, package setup, basis reconstruction and independent verification are outside its timing; eigenmode construction and Gram preparation are included in the full constructor comparison. No persistent cache, all-page matrix stack or new native workspace is introduced. Peak memory/RSS was not measured.

## Workload and numerical verification

The constructor saves its final 38-column state, while its assessment retains the full 64-column prefix arrays. The isolated harness therefore restores the pinned stratification and rebuilds the full beta.6 candidate factors outside timing. It requires those factors to reproduce every saved wave/inertial prefix and grid-support count exactly, then verifies **569 × 64 + 64 = 36,480** total norm calls. It does not extrapolate timings from the trimmed 38-column state.

Both isolated paths produce exactly equal complete prefix arrays and grid-support counts, including a derived heterogeneous/zero-count workload and the inertial family. Adjacent representable nonnegative thresholds around every measured prefix error exercise acceptance boundaries. Full before/after constructor comparison confirms exact equality of saved numerical scientific state and assessments, excluding only input function handles and the three existing named timers. Selected counts, statuses, labels, normalization, physical arrays, diagnostics and scientific tolerances remain compared.

The retained `TestGramPrefixAssessment` uses analytical singular values for crafted residual blocks. It covers neighboring values on both sides of a cutoff, zero and heterogeneous counts, nearly dependent and nonsymmetric Grams, roundoff-level errors, every prefix and inertial decisions. It passes with the retained original production loop. Its analytical oracle replaces the initial temporary copy of the old assessment routine, avoiding a test that merely duplicates production.

The three final study/assessment/regression MATLAB files have zero active, suppressed or blocking Code Analyzer findings. A setup-only array preallocation was added after timing; the measured numerical paths are unchanged. GPT-6 Astra extra-high reviewed the candidate, repaired workload, regression and deferral rationale. WVM's final numerical production remains identical to the #36 package combination that passed 36 installed construction cases and nine release-verification tests; this additional prefix regression also passes. Documentation/manifest checks from #36 remain valid because #34 changes no release metadata, canonical website source or generated website output.

## Cumulative result and next target

A fresh controlled original-series baseline uses WVM `abe98510ba3ad24276c2af2bd89c80b24209b568` and InternalModes beta.5 `8d9503e5c7c6e4b0432a5c30b42638829a8b3f37`. Compared with the retained post-#36 code, constructor medians are **23.575545 → 15.450600 seconds**: **8.124945 seconds saved, 34.46% less elapsed time, 1.526× speedup**. Both use the same explicit computation-thread setting and full-workload warmup. The saved numerical state and complete assessments excluding named timers match exactly. Raw cumulative timings and separate profile durations are included in the JSON.

This cumulative comparison is measured directly; it does not add the earlier per-issue percentages. The historical milestone's 31.155-second median and 46.998-second profile used a different revision/warmup/threading context and are not substituted into this comparison.

Recommend [#35](https://github.com/JeffreyEarly/internal-modes/issues/35) next. The retained profile places `eig(...)` at **7.192 seconds**, while the prefix loop is 1.574 seconds. First establish a stable threading baseline and refresh the native probe before forecasting gains; preserve complete eigenvectors, numerical parity, bounded workspaces, library thread safety, controlled nested threading and serial fallback. No #35 implementation is part of this goal.

**After each optimization, remeasure construction, reprofile, and update remaining priorities before starting the next target.** #34 may be reopened if a concrete prefix algorithm demonstrates worthwhile savings without changing assessment semantics. Foundations #10/#18/#20 and related #21/partial-eigensolver research remain unchanged. Tracking the experiment in InternalModes does not move WVM's count policy into the provider or add a provider dependency on WVM.
