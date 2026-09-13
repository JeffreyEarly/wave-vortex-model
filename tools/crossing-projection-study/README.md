# Surface-crossing buoyancy projection (#499)

The split projection removes the thin-layer convergence tail identified in #450. Across the same twelve frozen mixed states, the 0.1% coefficient-tendency target now passes at 13 vertical evaluation samples, compared with up to 65 for the original rule. The implementation is retained as an explicit assessment option and an authoring callback candidate. **Production quadrature remains unchanged:** the runtime benefit depends on whether crossing quadrature, rather than the modal inventory, requires the larger grid. No universal eight-point rule or automatic resolution policy is adopted.

## Mathematics and stable assembly

Let N²_star be the polynomial representation used for stratification and I_star(z) its integral from zero. Continue that polynomial algebraically above zero. The physical buoyancy remainder separates as

$$R_B=R_{\rm smooth}-I_\star(\max(z,0)).$$

This does not extend parcel density or change the upper-constant reference density. The production evaluator still enforces admissible parcel labels, signed displacement intervals, geometry, and its endpoint roundoff convention. `evaluateCrossingSplit` additionally evaluates R_smooth directly with the stable interval recurrence at the affected samples. Subtracting the O(amplitude) crossing after assembling an O(amplitude²) source would reintroduce cancellation, so the candidate assembles its sources with R_smooth first.

For positive surface elevation zeta, gamma=1+zeta/D and xi_c=-zeta/gamma. For each native WKB cardinal function ell_j, compute

$$b_j=\int_{\xi_c}^{0}\ell_j(\xi)I_\star(\gamma\xi+\zeta)\,d\xi.$$

Gauss nodes span this actual layer, regardless of its thickness. Adding b_j/q_j to the smooth vertical source makes the existing modal projector integrate the layer against each interpolated wave mode. The correction commutes with the horizontal Fourier transform and needs no mode-dependent horizontal grids. Nonpositive SSH has no layer correction. APV, zero-APV, inertial and mean-density tendencies, endpoint functionals, phase factors, and inactive wave padding retain their existing conventions.

This is a **quadrature load, not a pointwise acceleration**. Assessment `source` fields remain physical samples; `tendency` and `buoyancy` use the selected integration rule. The authoring subclass returns loads solely to measure the complete callback; it is not a supported transform or persistence interface.

## Accuracy evidence

[Convergence data](results/convergence.csv) contain 1,512 family rows (252 evaluations): constant and exponential stratification, amplitudes 0.01/0.1/1, clocks 327/901, Z=9/13/17/25/33/49/65, and layer orders 0/8/16. The domain, 129-point frozen modes, 8×8 retained horizontal inventory, label offsets, six families, and t0=-17 follow [#450](../nonlinear-resolution-study/README.md). Horizontal evaluation uses 64×64 samples.

The split reference uses 64×64×129 and 16 layer nodes. Controls refine horizontally to 96×96, vertically to 193 and 32 layer nodes, separately and jointly. All twelve references pass #450's per-family tolerance and reference-stability criteria without relaxation. An independent unsplit 64×64×1025 evaluation differs by at most 4.1e-6 relatively; it does not share the layer algorithm. [Reference data](results/references.csv) preserve both comparisons. Eight and sixteen layer points give the same assessed outcome throughout; the [figure](results/crossing-convergence.pdf) includes measured reference change rather than displaying zero error on the reference grid.

The first passing split Z is 13 for every amplitude/profile at both clocks. At Z=9, smooth-field resolution still fails. These are fixed-basis evaluation counts, not constructor defaults or proof that the modes themselves are resolved on thirteen samples.

Independent tests cover constant-stratification layer moments, variable-stratification weighted integrals, signed and zero SSH, directly evaluated smooth remainders through amplitude 1e-12, unchanged physical thermodynamic fields, all families at both clocks, unequal/zero wave pages, phase removal, and parcel-label rejection. The polynomial continuation and chosen layer order must themselves remain numerically resolved; this study does not qualify large crests or arbitrary mode/profile degrees.

## Cost and complete-callback comparison

For H positive-or-negative columns, H_plus positive-SSH columns, Z samples, Q layer nodes, profile degree P and WKB-map degree C, added work is

$$O(H_+ZP)+O(H_+Q(Z+P+C))+O(HZ).$$

The first term bounds the extra smooth-remainder recurrence at crossing samples. Cardinal interpolation contributes H_plus*Q*Z; polynomial and map evaluations contribute H_plus*Q*(P+C). These costs are linear in grid size at fixed P,C,Q, but those degrees remain explicit accuracy parameters. The immutable profile/map, Gauss rule and native interpolation data are prepared outside repeated callbacks. Existing field caches still own reconstructed state and invalidate when the clock or coefficients change.

The callback candidate inserts the load before the existing source FFT, retaining the 19-volume-transform schedule. The offline assessment uses additional diagnostic transforms to keep physical sources separate; those are not charged to the callback benchmark.

`benchmarkCrossingProjection` times the actual `coefficientTendency` lifecycle with registered nonlinear forcing, all six families, cold successive phase states, ten warm-up calls, five alternating trials of thirty callbacks, and setup excluded. Grids are 8×8×17/65 and 24×24×33/65, with three APV, four wave, two mean-density and three inertial modes, both boundaries, and amplitude 0.01. Every constructor passes its existing quadratic/boundary checks. A preliminary 24×24×17 attempt was rejected for 3.73% boundary-mode grid error against its 1% tolerance; that gate was preserved and the timing grid increased to 33.

[Runtime trials](results/runtime.csv) and [callback accuracy](results/runtime-accuracy.csv) retain timings and all-family errors against a refined split reference. Compare the smallest tested grid meeting the same 0.1% target for each method; a same-grid timing ratio alone is not an accuracy/cost comparison. The callback cases have their own horizontal inventories and factory-built modes; the twelve-state frozen-basis study remains the independent quadrature comparison.

| Profile | Horizontal grid | Original Z / ms | Split Z / ms | Runtime change |
| --- | --- | ---: | ---: | ---: |
| Constant | 8×8 | 65 / 3.05 | 17 / 1.92 | -37.2% |
| Constant | 24×24 | 65 / 8.52 | 33 / 6.91 | -18.8% |
| Exponential | 8×8 | 65 / 2.41 | 17 / 1.62 | -33.0% |
| Exponential | 24×24 | 33 / 6.58 | 33 / 7.16 | +8.8% |

The split candidate is 19–37% faster at the matched target in three cases. The exponential 24×24 case already passes at Z=33 with the original quadrature, so the split adds about 9% cost there. These are measured callback cases, not universal speedup factors.

The decision is to retain the explicit method and evidence, without paying its overhead unconditionally in production or weakening mode qualification. It can supply better-resolved reference projections for #500. A production integration would also need to preserve physical-source diagnostics and prescribed-forcing decomposition; the authoring load substitution is not exported as that API.

## Reproduction and verification

Use MATLAB R2026a, InternalModes 2.0.0-beta.4, and the manifest-compatible dependencies used by #450. Starting in the WVM authoring repository:

```matlab
addpath('tools/crossing-projection-study','tools/nonlinear-study')
runCrossingProjectionStudy
benchmarkCrossingProjection
plotCrossingProjection
assertSuccess(runtests({'UnitTests/TestBuoyancyCrossingProjection.m', ...
    'UnitTests/TestBoussinesqRHSAssessment.m', ...
    'UnitTests/TestBuoyancyIntervalRecurrence.m', ...
    'UnitTests/TestFreeSurfaceThermodynamics.m'}))
```

The numerical note and compiled PDF replace the original convergence figure with the direct comparison and add the split formula and operation cost. No website, manifest, released snapshot, default runtime policy, or persistence schema changes are included.

Verification: all 18 focused tests pass. Code Analyzer reports no findings in the changed/new MATLAB files. The eight-page note compiles without LaTeX warnings. `docs:check` validates 2,362 files and 4,827 routes with no validation errors, but retains the two existing generated-file differences (`docs/classes/developer-internals/wvdensitydiffusionintegrator/index.md` and `docs/version-history.md`); neither was edited. Whitespace, manifest, and repository-scope checks pass.
