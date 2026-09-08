# Issue #353: retained-band qualification with the corrected provider

> Current scope: the [adiabatic qualification handoff](Issue353AdiabaticQualification.md) supersedes this report's historical next-work recommendations. Numerical results and failed accuracy criteria below remain unchanged. Thin-layer diffusion research is #389; the long adiabatic application is #367; release/install/export work is #354.

This study distinguishes a numerically accurate eigensolve from a sufficiently large retained scientific mode band. It follows the merged row-equilibration correction in InternalModes #16 and WVM #383. The original #380 tables remain historical evidence with their original provider. No runtime API, model hierarchy, resolved-mode definition, transform fitting, package metadata or experiment pin changes.

## Question and fixed physical problem

Does the intended 217-mode, 513-sample linear configuration meet the declared QGPV and separate endpoint targets? Are the 325/433-mode comparisons stable enough to support that conclusion? The study first qualifies an independent physical-depth reference, then compares modal prefixes while holding sampling and the numerical eigensolve fixed, and reruns the existing public intended-resolution assessment with the corrected provider.

Use depth 4000 m, latitude 24 degrees, a 100 km horizontal wavelength (mode 5 on the 500 km seasonal domain), `N2=(5.2e-3)^2 exp(2z/1300)`, `g=9.81`, and `g0=-I`, `gd=I`, where `I` is the full-depth stratification integral. Both endpoints are active. MDA is independently retained with two modes and remains zero in this nonzero-horizontal-page experiment. From rest, impose the strict surface-anomaly source `10*pi/T*sin(2*pi*t/T)` with `T=365.25 days` and vertical diffusivity `1e-5 m^2/s`. Observe days 64 and 91.3125. Exact augmented matrix exponentials remove timestep error. The seed, nonlinear advection, drag and adaptive damping are excluded, as in the public linear assessment; these results cannot qualify a nonlinear production run.

## Independent reference and acceptance

Reuse #351's physical-depth Legendre weak formulation in `TestFreeSurfaceQGDiffusionQualification`, including physical pressure derivatives, buoyancy diffusion, the free-surface term and independent surface/bottom displacement-source actions. Increase the number of polynomials through 129, 193, 257 and 385 (the degree is one less). This is an independent diagnostic reference, never a replacement for the production resolved-mode transform.

The reference operator and physical comparisons use 2049-point Gauss-Legendre quadrature. Separately double reference-operator and comparison quadrature to 4097 points. A coordinate change between two QR-normalized polynomial representations preserves the same polynomial reference space when changing quadrature. No modal fitting or mixing enters the WVM controls.

Reference and candidate errors use common physical fields. QGPV and buoyancy are depth/horizontal RMS; SSH and each endpoint anomaly are horizontal RMS. The positive physical energy-norm state difference is one half of the norm of the sine-amplitude vector `[sqrt(w)*kh*phi; sqrt(w*N2)*eta; f/sqrt(g)*phiSurface]`. This retains cross terms and differs from comparing scalar energy inventories.

| Observable | Absolute tolerance | Relative tolerance |
| --- | ---: | ---: |
| QGPV RMS | `1e-13 s^-1` | 5% |
| Buoyancy RMS | `1e-10 m/s^2` | 0.1% |
| SSH RMS | `1e-8 m` | 0.01% |
| Each endpoint anomaly RMS | `1e-8 m` | 0.1% |
| Positive physical energy norm | 0 | 0.01% |

These are the previous study's explicit targets, not public API defaults or universal accuracy guarantees. Candidate differences must be below `absoluteTolerance + relativeTolerance*referenceMagnitude`. Reference changes must consume no more than one fifth of this allowance. Each endpoint is assessed separately: a surface-dominated combined norm is insufficient. The numerical comparison-quadrature rows measure changes in comparison errors. The analytical quadrature control below compares complete physical states on a common fine grid.

The independently refined reference meets all six reference allocations at both observation times. The 257/385 comparison consumes at most 0.00450 of its allocated one-fifth allowance, and doubling reference-operator quadrature consumes at most `5.30e-6` of that allocation. This establishes a stable reference for the specified targets, not a rigorous continuum error bound. A focused regression now protects the separate endpoint allocations.

## Fixed-sampling modal controls

The numerical control constructs one `WVTransformFreeSurfaceQG` with 1025 samples, 433 APV modes, two MDA modes and both endpoints. All four APV prefixes (84, 217, 325, 433) reuse that same scientific solve, physical grid and boundary modes. Restricting the existing physical weak matrices to each retained prefix and rebuilding its energy-coordinate diffusion page preserves the resolved Galerkin problem; it does not fit a new production basis.

The evolved modal QGPV is compared to the independent reference. Differentiating reconstructed pressure supplies a separate QGPV consistency measurement, recorded in its own CSV. The 217/433 and 325/433 comparisons expose the remaining finite-modal-reference uncertainty on one fixed sampling grid. A doubled common quadrature check protects the measured 433-mode error.

## Analytical resolved-mode control

An independent analytical exponential-stratification catalog supplies the same scientific APV family and the two canonical boundary modes. Retain 84, 217, 325, 433, 865, 1297 and 1729 APV modes. Assemble the existing physical weak diffusion page with 8193-point Gauss-Legendre quadrature and evolve with the same exact augmented exponential. This removes numerical eigensolve and sampled pressure-derivative errors from the retained-band comparison; it does not change the Galerkin equations or introduce a fitted basis.

The diagnostic uses raw analytical column normalization to avoid repeated all-mode evaluations during normalization. The existing diffusion page supplies energy coordinates. Column scaling preserves the physical solution, and the 84-mode day-64 bottom sine amplitude agrees with the independently depth-normalized control `-0.00151079010900586 m` within `1e-10 m`. The maximum analytical root residual is `4.44e-13`.

Repeat the 1729-mode evolution at 16385 quadrature points. Evaluate both evolutions on this fine grid using the identical raw modal coordinates and compare complete physical states. All six observables meet the reference allocation; the worst change consumes `1.74e-5` of the one-fifth allowance. These high-band cases are analytical diagnostics. Construction and sampling of a numerical WVM transform at 865–1729 APV modes have not been qualified.

## Results and interpretation

The analytical comparison against the independently refined physical-depth reference gives:

| Retained APV modes | QGPV error, day 64 | QGPV error, day 91.3125 | Bottom RMS error, day 64 (m) | Bottom RMS error, day 91.3125 (m) |
| --- | ---: | ---: | ---: | ---: |
| 84 | 44.292% | 35.425% | `1.09680e-3` | `2.32085e-3` |
| 217 | 13.411% | 9.823% | `2.01364e-4` | `3.62731e-4` |
| 325 | 7.485% | 5.422% | `7.97895e-5` | `1.36795e-4` |
| 433 | 4.905% | 3.539% | `3.66186e-5` | `5.91691e-5` |
| 865 | 1.749% | 1.256% | `3.36426e-7` | `2.63791e-6` |
| 1297 | 0.953% | 0.684% | `3.07709e-6` | `5.16045e-6` |
| 1729 | 0.619% | 0.444% | `2.41626e-6` | `3.42922e-6` |

The independent bottom RMS magnitudes are only `2.85127e-5 m` and `6.40977e-5 m`. Their respective absolute-plus-relative allowances are `3.85127e-8 m` and `7.40977e-8 m`. At 217 modes, QGPV, bottom anomaly and physical energy norm fail at both times. At 433 modes and each higher band, all five other observables pass their specified targets, but the bottom anomaly still fails. Reaching the QGPV target alone does not qualify the configuration.

The bottom error is nonmonotone even with analytical modes: the small 865-mode day-64 error is followed by a larger 1297-mode error. At 1729 modes the bottom errors are still 8.47% and 5.35% of the reference signal. This result supports an unresolved endpoint convergence limitation for this problem. It does not establish a new physics defect, and the favorable 865-mode value cannot establish convergence. A universal 1% criterion would not resolve the separate endpoint requirement.

The corrected public intended-resolution preflight agrees with the fixed-sampling diagnosis. Its day-64 217/433 QGPV difference is 12.536%, while the 325/433 reference change is still 5.741%. Thus 433 modes cannot serve as an adequately converged QGPV reference for this candidate. The independent analytical/reference comparison supplies the more informative 13.411% candidate estimate. The corresponding quarter-year candidate/reference differences are 9.202% and 4.177%, versus 9.823% against the independent reference. The public preflight alone remains a conditional comparison between finite resolutions.

The numerical controls also expose a smaller readout limitation. Pressure-derived QGPV and evolved modal QGPV differ by at most `5.78e-6` relatively on the fixed 1025-sample grid. At 433 modes, native bottom readout differs from the pressure-derived readout by `6.71e-8 m` RMS at day 64 and `1.49e-7 m` at day 91.3125. These are relevant to the tight endpoint allowance, but are hundreds of times smaller than the demonstrated retained-band bottom errors. The headline endpoint table therefore uses analytical readout. Neither numerical derivative consistency nor provider conditioning should be conflated with modal convergence.

## Next bounded increment

Keep #353 open. Before increasing production resolution or running nonlinear cases, diagnose the bottom endpoint error in the same linear problem with the existing scientific basis. Compare the independent reference and analytical modal solutions over a small fixed set of times, including the two reported here. Separate signed surface/bottom source and diffusion contributions to endpoint evolution, integrate the tendency discrepancies, and reconcile them with the measured endpoint-state error. Use the independent reference to distinguish an error in representing a state from an error introduced when evolving it in a finite band.

This should determine whether the nonmonotone endpoint response comes from resolved-band diffusion evolution and cancellation, or reveals a specific inconsistent operator/readout that warrants a correction. Preserve both active boundaries, the existing resolved transforms, predeclared separate endpoint allowances and v4-style interfaces. Propose an implementation change only after the discrepancy is localized and independently checked. Do not select a band from a favorable isolated cancellation. There is no jointly qualified candidate in this bounded study, so no new nonlinear or long seasonal run is claimed.

## Reproduction and scope

From the WVM root with its corrected dependencies and tests on the MATLAB path:

```matlab
addpath('UnitTests','Documentation/Validation');
result = TestFreeSurfaceQGDiffusionQualification.runRetainedBandStudy(outputFolder);
analytical = TestFreeSurfaceQGDiffusionQualification.runAnalyticalRetainedBandStudy(outputFolder);
publicAssessment = runShortSeasonalQGLinearPreflight(publicOutputFolder);
```

The bounded study writes `issue-353-band-errors.csv`, `issue-353-band-consistency.csv`, `issue-353-band-analytical.csv`, and local `band-states.mat`. The public preflight writes a new `issue-353-spatial-linear.csv` in its separate output folder; the new result is committed here as `issue-353-band-public-preflight.csv` to preserve the historical table. Use fresh output folders. No changed operator is appended to an existing trajectory.

Baseline WVM is `df53d8ad39a83360317821dc703960aa71e701e7`; InternalModes is `425e603e6af7f5914b5279262fdf47d18c627931`. Runs used MATLAB R2026a and the independent authoring dependency graph. The original experiment, saved trajectories, dependency pins and released snapshots remain untouched. Corrected-provider release/install/export and full scientific CI remain #354; the long seasonal experiment remains #367.

Verification: all seven `TestFreeSurfaceQGDiffusionQualification` tests pass, including the new separate-endpoint reference test. Both authoring studies and the corrected public preflight complete; reference and quadrature controls pass their allocations. Code Analyzer reports no findings in the changed MATLAB file. Documentation build/check passes with zero generated drift. Final whitespace, source scope and CSV-copy checks pass. No runtime source, package manifest or released snapshot changes; full scientific and install/export suites were not rerun for this diagnostic-only increment. No missing task assets prevented verification.
