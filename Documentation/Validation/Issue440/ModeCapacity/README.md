# APV diagnostic mode capacity

This bounded follow-up answers how many diagnostic modes the chosen grid can support and what those modes capture. The user prioritized speed and explicit limitations over finding an optimal count. No public transform, constructor tolerance, damping choice or evolution setting changes. The executable authoring method is [qualifyThermalAPVModeCapacity](../../../../tools/qualifyThermalAPVModeCapacity.m).

## Decision for the current target

Use **64 APV modes on 129 stored depths, with 513 physical integration points**, as a provisional diagnostic configuration. A cheaper vertical representation, **32 modes on 65 stored depths**, is also qualified below. Six remains a historical comparison control. These are tested choices below the measured grid limits; the study does not search for the largest possible count.

| Diagnostic stored depths | Constructor-selected count | First prefix rejected by its Gram check | Separately tested practical count | Worst physical mode-shape difference on a finer grid |
| --- | ---: | ---: | ---: | ---: |
| 65 | 38 | 39 | 32 | `1.67e-5` |
| 129 | 78 | 79 | 64 | `1.65e-8` |

Counts include the signed APV family in its stored physical label order; the two zero-APV endpoint responses and original thermal mean are additional families. Mode count is independent of the thermal coefficient count and of the frozen online damping band.

The constructor's default Gram tolerance is `1e-2`. At the accepted automatic prefixes, Gram errors are `0.00569` and `0.00634`; the next prefixes have errors `0.0230` and `0.0188`. Independent scientific mode-convergence errors are at most `2.71e-9`, below the unchanged `1e-6` tolerance. All fixed endpoint responses at all retained horizontal radii pass their separate `1e-2` boundary tolerance with measured errors below `3.78e-11`. These are different error measures and must not be interpreted as one universal accuracy percentage.

Automatic selection alone is insufficient for the diagnostic recommendation. When compared with the same band on a finer grid, the 38-mode and 78-mode transforms fail the additional 1% physical shape check: the first failures report APV physical mode labels 36 and 76, with differences approximately `0.0101` and `0.015`. The failures remain in [comparisons.csv](comparisons.csv). The first failure ends that case, so its maximum shape error and later state comparisons are unknown, not zero. Counts 32 and 64 pass all the bounded checks; the interval between each practical count and its rejected automatic count was not searched.

## What the modes capture

The test retains the existing target geometry and stratification: 500 km square, 4 km depth, 18 by 18 horizontal grid, latitude 24 degrees, `N2(z)=(5.2e-3)^2*exp(2*z/1300)`, 257 thermal directions and 385 thermal stored depths. It uses the same instantaneous manufactured surface-layer pressure and four nonzero mean coefficients as the original T9 target. Signed diagnostic weights are the negative and positive stratification integrals. The maximum retained horizontal wavenumber is `7.5398e-5 rad/m` (about 83.3 km minimum wavelength).

| APV modes | Stored depths | QGPV residual/source norm | Physical energy residual/source norm | Cached scalar diagnosis |
| ---: | ---: | ---: | ---: | ---: |
| 16 | 129 | 48.9% | 33.0% | 30 ms |
| 32 | 65 | 24.6% | 8.85% | 47 ms |
| 32 | 129 | 24.6% | 8.85% | 17 ms |
| 64 | 129 | 9.84% | 1.80% | 29 ms |

All use 513 integration points. The energy column is a positive physical energy **norm**, not an energy fraction; the QGPV column is a norm, not an enstrophy fraction. The original six-mode target left 78.7% QGPV norm unresolved. More APV modes improve the diagnostic coverage here; adding stored depths alone did not materially change the 32-mode coverage. APV projection is not a minimum-physical-energy fit, so physical-energy residuals need not decrease monotonically for arbitrary states.

For the 64-mode choice, construction took 3.24 s, initial preparation plus diagnosis 0.0964 s, and the median of three cached scalar calls 0.0292 s. The finer comparison transform took 15.05 s to construct once during qualification. Timings are local observations under shared host load with two computation threads; the non-monotonic small timings do not demonstrate that the smaller grid is slower or select an optimal configuration. No physical output volumes, I/O, campaign throughput or process memory benchmark is included.

## Reusable selection method

1. **Fix the scientific problem and sampling budget.** Record stratification, depth, rotation, gravity, signed endpoint weights, horizontal support, diagnostic stored depths and integration points. Preserve both endpoints. The boundary requirement depends on the maximum horizontal wavenumber as well as the vertical grid.
2. **Ask the shared constructor for its supported leading APV band.** Omit `apvModeCount` (or pass `[]`) and use `shouldCheckQuadraticAliasing=false` for offline diagnosis. Set `mdaModeCount=1` because the diagnostic retains the original thermal mean separately. Inspect `apvModeCount` and `constructionAssessment.apv`, including candidate count, prefix Gram errors and independent mode convergence. An explicit count is a request, not a measurement of capacity. If all candidates pass, report a tested lower bound rather than an established maximum. Constructor failures in endpoint resolution or inversion separation must remain visible.
3. **Check a modest band against a finer stored basis.** Construct the same count on `2*Nz-1` depths. Reuse `coefficientStateForTransform` at a stated mode tolerance and common physical quadrature. It checks every matched APV and endpoint polarization across the configured Fourier columns, including physical labels, inversion factors and normalization/phase alignment; the original objects remain unchanged. The unchanged scientific constructor checks run on both transforms. A failure is a sampling limit, even if the native Gram check passed. This follow-up uses a 1% diagnostic shape allowance and tests simple counts below the automatic limit instead of locating an exact maximum.
4. **Check the diagnostic calculation at fixed band.** Compare `apvDecomposition` at Q and 2Q on the same stored arrays, then compare the two grids at 2Q. Record APV and endpoint coefficient-magnitude changes separately before taking their maximum, and each residual norm's change relative to its source norm. Magnitudes permit independent eigenfunction sign conventions; physical labels must match. The 1% reporting allowance is distinct from the original T9 implementation-verification gates. Accepted cases here have coefficient-magnitude changes below `1.85e-9` and source-normalized residual changes below `9.41e-8`, well inside it.
5. **Report coverage and cost separately from numerical reliability.** A mode that the grid represents accurately need not capture much of a particular state. Retain the APV + zero-APV + mean + residual accounting, choose a practical count, and record actual residuals as the state evolves. A large real residual is not a reason to change sampling tolerances. A selected APV count does not establish the thermal evolution's nonlinear resolution or add independent information beyond its represented state.

The published `WVTransformFreeSurfaceQG.assessVerticalResolution` also assesses APV counts and a conservative horizontal limit. For a known horizontal grid, constructing the diagnostic transform directly avoids an unnecessary search over horizontal wavenumbers and provides checks for the actual retained support.

## Reproduction and verification

From a clean supported MATLAB path with `configureCIEnvironment` and the beta.5 snapshot:

```matlab
addpath('tools');
maxNumCompThreads(2);
results = qualifyThermalAPVModeCapacity(outputDirectory);
results.capacity
results.comparisons
results.coverage
```

The utility defines this target case explicitly. Its default cases are automatic counts at 65 and 129 depths, then explicit `(Nz,count)` pairs `(65,32)`, `(129,16)`, `(129,32)`, `(129,64)`. This is a qualification driver, not a new runtime selection API. It records rejected cases and continues; successful MATLAB completion alone does not mean every candidate passed. Review the status and failure columns. It reuses the existing WVM constructor, transfer comparison and diagnosis; it does not introduce another mode solver or projection implementation.

The evidence was collected in two coherent batches: initial automatic counts plus 16/32 modes at 129 depths, then the two conservative choices after the automatic limits failed the separate shape check. The final driver adds explicit physical-label matching to the coefficient-magnitude comparison; that path was executed in the supplemental batch. The first batch used the same stored physical label order. The output schemas and numerical definitions are unchanged. Successful cases were not rerun after documentation-only edits.

The source baseline is v5 merge `9d55ad2b6c0d16db529a39990aad4b89f9e835a8`. Both batches use MATLAB R2026a Update 4 and uniquely resolved `OceanKit/InternalModes-2.0.0-beta.5`, with Distributions 2.0.0, SplineCore 2.2.0, chebfun 5.7.0, NetCDF 1.0.2 and ClassAnnotations 1.2.1. Historical R2025b T9 results remain historical. No installed snapshots or historical experiment pins were modified.

The [capacity](capacity.csv), [comparisons](comparisons.csv), [coverage](coverage.csv) and [environment](environment.csv) tables combine both batches. Per-case prefix, convergence and boundary tables preserve the constructor evidence. A consistency audit confirmed six successful constructions, four accepted diagnostic bands, two recorded shape-limit failures and 36 accepted-case observable rows. Code Analyzer, focused shared diagnostic tests, documentation consistency and final scope checks are recorded in the parent [verification ledger](../VerificationLedger.md).

Remaining limits: one manufactured target state, no nonlinear trajectory or APV quadratic-product qualification, no proof of the largest acceptable prefix, no universal grid-to-count ratio, and no guarantee that the same stored grid or 513-point physical quadrature will suffice for different stratification, horizontal bandwidth or a richer thermal state. The shape check is a positive physical polarization norm with phase/normalization alignment; scalar residual and coefficient-magnitude comparisons are not a pointwise guarantee for arbitrary superpositions or a signed/phase coefficient comparison. This follow-up does not independently measure convergence of the source norms used as denominators. The caller configures and verifies the dependency path; the qualification utility records it without enforcing a particular installed version. Reapply the bounded method when the scientific configuration changes.
