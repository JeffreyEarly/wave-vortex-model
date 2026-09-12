# Assembled Boussinesq RHS resolution (#450)

The remaining #450 assessment is complete. New offline assessment functions evaluate the **same modal state and source projector** on independently refined horizontal and vertical grids. They cover the assembled divergence, geometry, pressure, and displacement-buoyancy terms, report all six coefficient families, and reject an accuracy claim when its reference is insufficiently resolved. They do not change numerical evolution, retained-mode defaults, forcing, persistence, or the stored quadratic activation gate.

The principal finding is a thin-layer buoyancy integration error. For these smooth mixed states, horizontal refinement is already a small effect at 8×8 samples. Vertical convergence can be much slower, especially at small surface amplitude. A successful sampled-quadratic mode assessment alone does not detect this state-dependent effect.

## What is held fixed

Baseline: v5 `6327b9a57fe4fca44f4bc3fd5a34c188eaef4b3f`. The study uses constant N²=1e-4 s^-2 and exponential N²=1e-4 exp(z/650) s^-2, a 100 km ×100 km ×1 km domain, and a frozen 8×8 horizontal modal inventory with 3 APV, 4 wave, 2 mean-density, 3 inertial, and both active boundary modes. A 129-point WKB representation supplies the fixed modal functions; the wave EVP starts at 256 points and construction uses its existing convergence checks. Evaluation-grid refinement does not solve new modes, refit coefficients, alter modal normalizations, or introduce new output wavenumbers.

`manuscriptEvolutionOperators(...).seed("mixed",1)` defines the initial coefficient arrays once per profile. All six families are multiplied by epsilon=0.01,0.1,1. The two phase clocks are 327 and 901 s with t0=-17 s. Peak SSH is approximately 0.0282, 0.282, and 2.82 m respectively. Mean-density offsets keep parcel labels inside the reference domain. These are bounded smooth ocean states, not a turbulence or near-dry-depth survey.

The source evaluator uses the production displacement convention, upper-constant reference density, divergence form, modal pressure, thermodynamic recurrence, and mapped dense derivatives. Horizontal antialias truncation is disabled for the offline evaluation; all original retained wavenumbers are extracted after evaluating the products. There is no claim that these study objects have passed the separate runtime activation gate.

## Fixed projection and endpoint terms

A volume source functional has the form

$$L[s]=C\sum_j q_j\Phi(z_j)s(z_j)+d_b s(-D)+d_t s(0).$$

Preparation recovers the fixed normalization C from the stored interior pairing, checks that this factorization reproduces it, and separates the endpoint residuals. Evaluation interpolates the frozen modal functions in their Chebyshev/WKB coordinate, changes only quadrature nodes and weights, and retains the endpoint functionals exactly. Interpolating an endpoint delta contribution as an ordinary density would produce a false resolution dependence.

Wave pairings retain both propagation signs, analytical phases, per-wavenumber counts, and the same equivalent depths. APV, zero-APV, inertial, and mean-density pairings keep their original normalization. The boundary solve is unchanged. At the original grid, all-family tests agree with the production source/projector to the existing roundoff tolerances. A separate polynomial transport test differentiates an analytic continuum source independently.

## Reference qualification and metrics

Horizontal sweeps use N=8,12,16,24,32,48,64 in both directions, holding the vertical reference grid fixed. Vertical sweeps use Z=9,13,17,25,33,49,65,97,129,193,257 with 64×64 horizontal samples. Each amplitude/phase case begins with a 64×64×257 reference and checks 96×96 horizontally, 1.5 times as many vertical intervals, and both refinements together. If needed, the primary vertical interval count doubles, up to Z=1025. The small-amplitude cases required Z=513 or 1025; other cases used 257. The largest independent check therefore used 96×96×1537 samples.

For each family f separately, let r_f be the reference tendency, e_f the candidate-reference Frobenius difference, and delta_f the largest difference between the primary reference and its three refinements. Acceptance requires

$$e_f+\delta_f\le10^{-3}\lVert r_f\rVert_F+10^{-18},\qquad \delta_f\le0.01\left(10^{-3}\lVert r_f\rVert_F+10^{-18}\right).$$

The absolute allowance is in each family's native coefficient-rate units; different physical units are never summed. Both directional reference checks are mandatory. Missing checks, nonfinite reference values, or inadequate reference stability return `reference-inconclusive`; a resolved reference with excessive candidate error returns `rejected`. Acceptance is `assessed` for this one state, phase, and fixed basis. The reference differences are empirical checks, not rigorous error bounds.

All 12 references passed without relaxing these tolerances. [convergence.csv](results/convergence.csv) records 1,296 family rows for 216 candidate evaluations; [references.csv](results/references.csv) records each family's check. [sources.csv](results/sources.csv) separately records the four sources in the common retained Fourier columns before vertical projection. Its norms are discrete spectral Frobenius norms on the reference vertical nodes, not physical-space RMS norms. Error in omitted output modes and error in the frozen modal representation are outside this fixed-basis comparison.

## Result and figure

The [figure](results/vertical-convergence.pdf) shows the worst family/phase relative discrepancy plus the measured reference change. Dotted lines show the latter alone, so matching the primary reference grid is not presented as zero error. The declared 0.1% line is an assessment target, not a universal simulation tolerance.

| Profile | Amplitude multiplier | Peak SSH (m) | First tested Z passing at both clocks |
| --- | ---: | ---: | ---: |
| Constant | 0.01 | 0.0282 | 65 |
| Constant | 0.1 | 0.282 | 25 |
| Constant | 1 | 2.82 | 13 |
| Exponential | 0.01 | 0.0282 | 65 |
| Exponential | 0.1 | 0.282 | 17 |
| Exponential | 1 | 2.82 | 13 |

These counts apply with the refined horizontal grid, the stated modes, and these states. They are not recommended defaults. Horizontal discrepancies at fixed vertical resolution were below 7e-6 even on 8×8 samples. [qualified-grids.csv](results/qualified-grids.csv) records the vertical thresholds and reference margins.

For constant stratification and valid parcel labels, the upper-constant reference convention gives

$$R_B=-N^2\max(\xi+\alpha\zeta,0).$$

For positive SSH the nonzero layer has thickness zeta/gamma, and its unweighted vertical integral is -N² zeta²/(2 gamma). As the amplitude shrinks this layer narrows, although its integrated effect is quadratic. A fixed endpoint quadrature weight samples a pointwise O(zeta) value and can therefore contaminate relative accuracy in a much smaller quadratic tendency. This explains why smaller amplitude is harder here; it is not evidence of increasing absolute physical error as amplitude vanishes.

Removing only the projected R_B contribution from the discrepancy reduces the remaining vertical error to at most 3.2e-8 for Z>=17. This is a term-decomposition diagnostic, not an alternative physical model. It identifies the thermodynamic crossing layer, rather than the smooth rational factors, as the dominant convergence tail in these cases. The same convention contributes a crossing layer with variable stratification.

Independent analytic controls set eta=alpha*SSH, so parcel labels equal xi, and use SSH/D=0.05,0.2,0.5. They test the complete source algebra against explicit derivatives at increasing horizontal resolution, including 1/gamma and 1/gamma². They are manufactured source fields, not claimed retained modal states or realistic high-speed flows. All four sources converge to their analytic expressions; nonzero-source relative discrepancies at N=64 are below 1e-11. Zero sources use an absolute roundoff allowance. See [rational-controls.csv](results/rational-controls.csv). These controls demonstrate why polynomial dealiasing cannot be taken as exact qualification of rational geometry.

## Assessment interface

For an 8×8 configured transform `w`, with InternalModes available:

```matlab
snapshot=WVInternal.prepareBoussinesqRHSAssessment(w);
candidate=WVInternal.evaluateBoussinesqRHSAssessment(snapshot,[w.Nx w.Ny 33]);
reference=WVInternal.evaluateBoussinesqRHSAssessment(snapshot,[64 64 257]);
horizontal=WVInternal.evaluateBoussinesqRHSAssessment(snapshot,[96 96 257]);
vertical=WVInternal.evaluateBoussinesqRHSAssessment(snapshot,[64 64 385]);
joint=WVInternal.evaluateBoussinesqRHSAssessment(snapshot,[96 96 385]);
report=WVInternal.assessBoussinesqRHSResolution(candidate,reference,{horizontal,vertical,joint});
```

Choose grids that include all original horizontal modes and refine the references until `referencesStable` is true. Preparation copies the caller's state; later coefficient/clock changes on the caller do not alter the snapshot. Treat the prepared snapshot and its nested transform as immutable. The functions assess one unforced RHS and do not include optional forcing or diagnostics in the physical source.

## Reproduction and verification

MATLAB R2026a Update 4, Apple Silicon, InternalModes v2.0.0-beta.4, and the same manifest-compatible dependency setup as #484. With WVM on the path:

```matlab
addpath('tools/nonlinear-resolution-study','tools/nonlinear-study')
runBoussinesqResolutionStudy
runRationalGeometryControls
plotBoussinesqResolution
assertSuccess(runtests('UnitTests/TestBoussinesqRHSAssessment.m'))
```

The four focused tests pass: native all-family sources/projections at both clocks and stratifications; an independent polynomial transport source; unequal and zero wave pages; snapshot isolation and reference-status rejection controls. The analytic rational controls also pass. Code Analyzer reports no findings in the new MATLAB files and no blocking production findings. Documentation validation passes 2,362 files and 4,827 routes; generated-file comparison still reports only the existing density-diffusion index and version-history differences. No website content or package manifest is changed.

The numerics note includes the vector figure and a concise account of this finding. The asymptotic RHS cost is unchanged, but the required evaluation Z depends on state amplitude and profile regularity. A useful next numerical optimization is projection/quadrature that explicitly resolves the reference-surface crossing; that implementation is not necessary to complete this assessment and is not silently substituted here. Mode-truncation, trajectory, and restart evidence from the earlier #450/#483 work remains separate. No universal nonlinear resolution policy or long-time conservation claim follows.
