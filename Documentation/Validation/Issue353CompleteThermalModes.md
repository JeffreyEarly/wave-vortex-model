# Diffusion research #389: complete balanced thermal modes

A complete 257-dimensional balanced thermal basis in WKB polynomial space meets all six previously declared observable targets at all five seasonal observation times. It resolves the surface buoyancy gradient without changing diffusivity, strict forcing, either active boundary, or the existing APV/zero-APV transforms. This is a reproducible authoring proof of concept for a separate diffusion solver, not a primary WVM representation, runtime implementation or nonlinear qualification.

The primary wave-vortex model must remain entirely in adiabatic APV, wave, zero-APV boundary and applicable mean modes. Diffusion may act as a closure projected onto that space, with accuracy limits reported through the existing response-estimation API. Thermal-coordinate development and the application-specific thin-layer continuum targets belong to [research issue #389](https://github.com/JeffreyEarly/wave-vortex-model/issues/389), outside the v5 milestone. They do not block #353 or #354. This scope correction supersedes the earlier recommendation to integrate thermal coordinates into core v5; the numerical findings below are unchanged.

## Physical problem and acceptance

Retain the #385/#387 problem: depth 4000 m, latitude 24 degrees, horizontal wavelength 100 km (mode 5 in a 500 km domain), `N2=(5.2e-3)^2*exp(2*z/1300)`, gravity 9.81 m/s², and buoyancy diffusivity `1e-5 m²/s`. Start from rest with surface interior-displacement tendency `10*pi/T*sin(2*pi*t/T)`, `T=365.25 days`, no direct interior QGPV or bottom source, and both endpoints active. MDA, nonlinear advection, seed, drag and damping remain excluded. Observe days 1, 8, 32, 64 and 91.3125.

Use the existing RMS absolute-plus-relative allowances, separately for QGPV (`1e-13 + .05*reference`), buoyancy (`1e-10 + .001*reference`), SSH (`1e-8 + .0001*reference`), each endpoint displacement (`1e-8 + .001*reference`), and positive physical energy norm (`.0001*reference`). These retain the units and spatial averaging in `studyComparison`. A large surface signal cannot mask bottom error. Reference/control differences receive one fifth of these allowances. There is no universal one-percent criterion.

## Construction and relation to the notes

The literature notes `gpt-free-surface-qg-space-time-diffusion-modes.tex` and `gpt-free-surface-qg-thermal-mode-evolution.tex` explain why slow-mode truncation and overlapping APV/thermal coordinates can fail. A complete thermal basis preserves cancellations required by strict forcing. Diagonalizing an already truncated APV operator cannot recover missing directions. The later notes recommend forward exponential propagation rather than inverse-decay interaction coordinates and repeated rebasing.

Here the full pressure trial space contains all polynomials through degree `n-1` in the WKB coordinate

$$s(z)=2\frac{e^{z/1300}-e^{-4000/1300}}{1-e^{-4000/1300}}-1.$$

The helper uses Legendre polynomials in `s` to assemble this space; it is the same complete polynomial space sampled on `n` WKB-stretched Chebyshev points. These assembly polynomials are not the proposed evolved modes. No APV eigensolve or fitted reference trajectories select the space. Independent physical-depth Legendre polynomials supply the comparison reference.

For a trial streamfunction, reconstruct the existing displacement, physical buoyancy and QGPV definitions, including the free-surface correction. Assemble the same physical weak diffusion form as `WVInternal.densityDiffusionPage`, with both endpoint degrees of freedom unconstrained. Positive physical-energy QR coordinates condition the complete space. In those coordinates the generator and surface-source column are

$$A=E_z^* W\kappa_T B_z,\qquad s_0=-f\,\Phi_0^*.$$

Here `E_z` reconstructs the vertical derivative of total displacement, `B_z` the derivative of physical buoyancy, and `Phi_0` surface streamfunction. The source sign follows the existing weak boundary forcing. There is no bottom boundary clamp or buoyancy-flux load. APV generalized-energy boundary weights do not enter these physical matrices.

Solve `A U = U Lambda` and retain **every** direction, including null directions. Physical thermal modes are the reconstructed columns of `U`; amplitudes use `U\state`, not an assumed energy-orthogonal projection. Advance the harmonic source using scalar forward exponential responses, retaining the rest-state transient. The implementation separates cancelling small-argument terms using series and `expm1`; a separate regression checks zero time, very small time, null decay and complex source amplitudes. The independently augmented full matrix exponential does not use eigenvectors.

These are complete discrete balanced thermal modes. The evidence qualifies their combined response for this problem; it does not certify every highest-index eigenvector as a converged continuum eigenfunction. Existing scientific APV and wave transforms, normalizations and hierarchy are unchanged. A separate diffusion solver could use this complete representation with explicit conversion/reconstruction. It must not replace or augment the primary WVM's adiabatic state; diffusion projected onto the primary state retains that state's resolution limits.

The notes' collocation example has an inactive bottom, and older coupled results use flux forcing. Neither is copied as qualification of the present case. Retaining the existing weak operator also avoids assuming its finite-resolution equivalence to the notes' composed collocation operator.

## Results

The common physical-depth observation/assembly quadrature has 2049 points; the reference has 385 physical-depth polynomials. Each row below covers all six observables at all five times.

| Complete WKB directions | Checks passed | Worst error / allowance | Worst observable and time |
| --- | ---: | ---: | --- |
| 129 | 26 / 30 | 7.8464 | Bottom, day 32 |
| 257 | 30 / 30 | 0.01249 | Bottom, day 8 |
| 385 | 30 / 30 | 0.001308 | Bottom, day 91.3125 |

At 257 directions, the worst full-depth and upper-100-m buoyancy-gradient relative errors are `4.95e-8` and `4.97e-8`. These gradient comparisons supplement the existing observable contract; the regression uses a stated `1e-5` gradient guard. FFT-backed cosine transforms, the Chebyshev coefficient derivative recurrence and the physical WKB Jacobian reproduce the analytic native-grid buoyancy derivative to `3.74e-13` relative. The provider's independent native differentiation matrix gives `5.52e-13`.

At this count, the eigenvector condition number in positive-energy coordinates is 20.81 and the relative eigen residual is `2.10e-15`. The maximum real eigenvalue is `4.79e-23 s^-1`, consistent with roundoff; no eigenvalue is clipped or dropped. Direct surface-source reconstruction has depth-RMS QGPV tendency `1.44e-23 s^-2` and maximum endpoint-tendency error `1.44e-18 m/s`. The zero-diffusion control's worst depth-RMS reconstructed QGPV is `7.22e-17 s^-1`. These are finite-precision residuals, not claimed exact floating-point zeros.

The worst forward-modal versus independently augmented-matrix difference is `0.003403` of the observable allowance at 257 modes, below the one-fifth control allocation. At 385 it is `0.02505`, also below that allocation. Roundoff sensitivity of the stiff direct exponential grows with resolution; the comparison therefore uses physical error allowances, not a claim that more points improve every numerical diagnostic.

For the candidate 257-mode configuration, independently doubling **assembly** quadrature to 4097 while retaining the same observation grid changes reconstructed states by at most `0.003109` of the full allowance. Refining the physical-depth reference from 385 to 513 changes its states by at most `0.0007630` of the full allowance. Both pass the one-fifth allocation. These compare reconstructed state differences, not differences between reported error norms.

## Boundary-weight investigation

The preceding bounded trials tested 32 APV configurations, each at the same five times and six observables. None satisfied the bottom target throughout. The best worst-time result was about 40.05 times its allowance. The committed weight CSV retains all 960 observations, including signed `surfaceLength` (`g0=-N2(0)*surfaceLength`), `g0`, `gd`, APV count and quadrature count. A zero weight here is an APV basis limit; it does not deactivate the physical endpoint.

The initial localized-weight investigation also exposed a separate analytical catalog root-finding defect: the negative-branch Bessel determinant could become an unresolved sign jump. [InternalModes PR #17](https://github.com/JeffreyEarly/internal-modes/pull/17), commit `58d8a12`, cancels known exponential factors before root finding. All 283 provider V2 tests pass, including spectral comparisons and direct boundary residuals for 5/10/20/50 m surface weights. This correction supports the analytical weight controls; it is not the explanation for the remaining finite-band seasonal error and is not needed to assemble the complete thermal operator.

## Reproduction and verification

With the corrected authoring dependencies and `UnitTests` on the path:

```matlab
a = TestFreeSurfaceQGDiffusionQualification.runCompleteThermalStudy(baseFolder);
b = TestFreeSurfaceQGDiffusionQualification.runCompleteThermalStudy(quadratureFolder,counts=257,assemblyQuadratureCount=4097);
q = TestFreeSurfaceQGDiffusionQualification.compareCompleteThermalStudies(a,b);
c = TestFreeSurfaceQGDiffusionQualification.runCompleteThermalStudy(referenceFolder,counts=257,referenceCount=513);
r = TestFreeSurfaceQGDiffusionQualification.compareCompleteThermalStudies(a,c);
```

The baseline writes `issue-353-complete-wkb-errors.csv` and `issue-353-complete-wkb-checks.csv`. Save `q` and `r` using `writetable` with the committed `-quadrature-control.csv` and `-reference-control.csv` filenames. The comparison helper compares reference states when reference counts differ, otherwise candidate states. All comparisons use the same physical observation quadrature.

The weight CSV is reproduced with `runSurfaceWeightStudy`: defaults for lengths `[5 10 20 50 100 650]`, APV counts `[217 433]` and quadrature 4097; lengths `[2 5 10]`, counts `[433 865]` and quadrature 8193 for each of `bottomWeight=0` and `bottomWeight=N2(-4000)*10`; then lengths `[0 -5 -20 9.81/N2(0)]`, counts `[433 865]` and quadrature 8193 with the default bottom weight. Reference count is 385 throughout.

All 11 affected diffusion-qualification tests pass locally in MATLAB R2026a, including the new complete-mode and small-time/null-mode regressions. Code Analyzer's unused local output was removed. WVM documentation validation passed with zero generated differences; no website source changed. Provider documentation generation succeeded, but that repository has no separate `docs:check` helper. Full/exhaustive scientific and clean-install/export suites are deferred to their existing integration/release gates. No missing task assets prevented this proof of concept.

The WVM baseline is `013f9a74` (PR #387, stacked on #385). Provider native-grid behavior uses the corrected `425e603e` baseline; the analytical weight trials additionally use `58d8a12`. Released packages, dependency manifests, experiment pins, saved trajectories and snapshots remain untouched.

## Separate research follow-up and primary-model work

The bounded diffusion proof of concept succeeds. A complete 257-direction thermal representation is a credible separate-solver candidate where 217 APV modes plus two boundary modes were insufficient for the stated seasonal target. This is a response-resolution result, not a global mode-count prescription, a whole-model performance benchmark or a reason to change WVM's coordinate families.

PR #388 is a research draft under #389. Before any code adoption, select an independent experiment/optional-code location and isolate its thermal-specific tests from required core WVM qualification. Preserve this report and its data as scientific evidence. Further thermal evolution, nonlinear coupling and performance work can proceed if separately prioritized; they are not the next core v5 increment.

For the primary model, #353 owns the audit of adiabatic reconstruction, dynamics, projected-closure correctness, bounded refinement and restart evidence. Its existing response API must disclose unresolved seasonal accuracy; removing the seasonal research target from a release gate does not make that simulation continuum-qualified. #354 retains corrected-provider release/export, supported-example adoption and full scientific CI. #367 retains the optional long adiabatic seasonal experiment; a thermal-coordinate solver would be a distinctly identified experiment. Review the independent analytical APV correction in InternalModes #17 on its own numerical merits.
