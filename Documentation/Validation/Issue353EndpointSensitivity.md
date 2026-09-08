# Issue #353: high-band endpoint sensitivity

> Current scope: the [adiabatic qualification handoff](Issue353AdiabaticQualification.md) supersedes this report's historical next-work recommendations. Numerical results and failed accuracy criteria below remain unchanged. Thin-layer diffusion research is #389; the long adiabatic application is #367; release/install/export work is #354.

The nonmonotone high-band differences in PR #380 are primarily a numerical eigensolve error. Equilibrating the generalized eigenproblem's rows reduces the fixed-band error against independent analytical modes and removes the observed nonlinear endpoint discrepancy. The WVM resolved basis, sampling policy, physical equations, and class hierarchy are unchanged. This does not qualify the retained bandwidth of the seasonal experiment.

## Configuration and controls

The isolated problem uses the existing seasonal vertical configuration: depth 4000 m, latitude 24 degrees, `g=9.81`, `N2=(5.2e-3)^2 exp(2z/1300)`, and `g0=-I`, `gd=I`, where `I` is the full-depth integral of `N2`. Both endpoints are active. Retain exactly 84 APV modes and two canonical zero-APV endpoint modes. MDA is identically zero in this forced nonzero horizontal page; the nonlinear confirmation independently retains two MDA modes.

The horizontal wavelength is 100 km, equivalent to meridional mode 5 on the 500 km seasonal domain. Apply the strict surface-anomaly source with amplitude `10*pi/T`, annual period `T=365.25 days`, and zero phase, starting from rest. Vertical diffusivity is `1e-5 m^2/s`. The isolated response uses an augmented matrix exponential at day 64, excluding the seed, advection, drag and adaptive damping. These controls separate eigensolve and spatial error from time integration error.

The constructor normally couples `nEVP=max(96,3*(Nz+4))` to the sampling count. This study instead:

1. Holds the *same APV and boundary basis objects* at `nEVP=783`, and changes WKB-Chebyshev sampling to 257, 385 and 513 nodes.
2. Holds 385 samples and 84 APV modes, and changes `nEVP` to 519, 783, 1167 and 1551.
3. Replaces only sampled `N2z` with its analytic derivative, then replaces all interpolated modal fields and stratification with direct evaluation on the operator quadrature.
4. Reconstructs endpoints independently from the APV Robin conditions, retaining the original diagnostic traces as the production result.
5. Compares with the independent exponential-stratification Bessel solution at the *same 84-mode band*, using analytical boundary modes and direct physical fields. Doubling its operator quadrature from 771 to 1543 points changes the bottom amplitude by `5.09e-16 m`; the largest characteristic-root residual is `2.24e-14`.

All numerical discrete transforms retain strict Gram and quadratic-aliasing certification. No transform fitting, mode mixing, altered physical boundary conditions, or silent truncation is used. The historical unscaled eigensolve appears only as a local control in the authoring script.

## Fixed-band analytical comparison

The analytical day-64 sine amplitudes are `2.66531682392831 m` at the surface and `-0.00151079010900586 m` at the bottom. These are amplitudes; divide by `sqrt(2)` for horizontal RMS. They are finite-band references, not continuum truths.

At 385 sampling nodes, using the ordinary sampled operator:

| nEVP | Original bottom error (m) | Equilibrated bottom error (m) | Original QGPV relative error | Equilibrated QGPV relative error |
|---:|---:|---:|---:|---:|
| 519 | 1.11e-8 | 6.56e-11 | 1.86e-7 | 4.29e-11 |
| 783 | 8.28e-8 | 2.72e-9 | 9.88e-7 | 5.99e-11 |
| 1167 | 2.05e-6 | 1.06e-9 | 8.64e-6 | 9.07e-11 |
| 1551 | 2.74e-6 | 2.40e-9 | 5.11e-5 | 2.62e-10 |

Across all controls, the worst eigendepth relative error falls from `1.38e-3` to `7.46e-8`. The positive physical energy-norm response error falls from `6.46e-8` to `3.99e-11`. More solver points had amplified roundoff in the original pencil; they did not establish a better reference.

With one original basis held fixed at 783, changing sampling varies the bottom amplitude by less than `1e-9 m`; after equilibration it varies by less than `8e-12 m`. Changing only `N2z` has negligible effect. Direct modal evaluation changes the original result by at most approximately `5.6e-9 m`, well below the micrometre eigensolve discrepancy. Thus neither the stretched-coordinate derivative nor quadrature is the dominant defect in this case.

For finite nonzero endpoint accelerations, the analytical relations are `Gs=(1+g/g0)Fs` and `Gb=-(g/gd)Fb`. Their independent endpoint readout changes the original bottom result by only about `3e-9 m`. Following equilibration, that discrepancy can reach `6.23e-9 m`, comparable to the remaining nanometre response error. Raw boundary-trace residuals therefore do not uniformly improve and cannot alone establish trajectory accuracy. The production readout is unchanged.

The study also applies each diffusion generator to a deterministic matched-mode coefficient vector, aligns individual mode signs, reconstructs the physical tendency on one common quadrature, and measures the positive physical energy norm. The largest tendency difference falls from `1.79e-4` to `2.84e-6` relative to the analytical construction. This comparison includes small differences in the depth-normalized modal fields (about `3.7e-6`); it is a physical tendency comparison, not a certified operator-norm error bound. The independently forced response is insensitive to a consistent rescaling of modal coordinates and gives the stronger QGPV evidence above.

## Minimal provider correction

For `A*v=lambda*B*v`, divide each equation by the largest absolute entry in that row across both matrices. A zero row uses scale one. This invertible left scaling preserves the eigenvalues and native eigenvectors in exact arithmetic; it makes interior derivative and endpoint equations comparable for the numerical QZ solve.

Numerical rejection of nearly infinite generalized modes must use the same scaled `B` as the solve. Keeping the old numerical metric there admits spurious modes and is rejected by existing APV tests. The original physical `A` remains the input to zero-mode classification, and original matrices remain available for matrix-level diagnostics. There is no new public option or family-specific dispatch.

The broader provider tests exposed one scale-sensitive MDA assertion: its original relative error divided by a nearly zero opposite-boundary trace of a trapped mode. The measured surface residual is at most `2.69e-12`, or `1.53e-10` against the mode's full-depth derivative scale. The test now includes `max(abs(G))/D` in its denominator at both endpoints, retaining the `2e-8` tolerance and all zero/negative/inactive-boundary checks. Production MDA behavior was not special-cased to satisfy this test.

## Nonlinear confirmation

Repeat only PR #380's three implicated `[24 24 Nz]` cases with `Nz=257,385,513`, 84 APV modes, two MDA modes, both active boundaries, the same deterministic 1 cm seed, strict seasonal source, nonlinear advection, diffusion and quadratic drag. Adaptive damping is omitted as in the original fixed-band comparison. Integrate to days 32 and 64 with actual one-day ETDRK4 steps. Reuse the existing physical comparison, Fourier accounting, budgets and tolerances; MDA remains exactly zero.

| Comparison against Nz=513, day 64 | Original bottom relative difference | Corrected bottom relative difference | Corrected bottom RMS difference (m) | Corrected QGPV relative difference |
|---|---:|---:|---:|---:|
| Nz=257 | 0.224% | 0.0000213% | 2.28e-10 | 2.06e-10 |
| Nz=385 | 0.341% | 0.0000879% | 9.39e-10 | 3.67e-10 |

Both days meet the original study's endpoint allowance (`0.1%` relative plus `1e-8 m` RMS). The 385/513 reference change is less than `0.000871` of that allowance, comfortably inside its one-fifth reference allocation. This resolves the bounded endpoint sensitivity, not the separate 56/84-mode discrepancy or the 217/325/433-mode intended-resolution reference limits. The earlier tables remain historical evidence with their original provider.

## Reproduction and verification

Use the independent authoring graph with the provider correction; do not change experiment pins or append new operators to old saved runs. From the WVM root with dependencies and `UnitTests` on the MATLAB path:

```matlab
addpath('Documentation/Validation');
r = runQGEndpointSensitivityStudy('endpoint-study');
e = TestShortSeasonalQGSpatialAccuracy.runEndpointConfirmation('endpoint-study');
```

The three committed `issue-353-endpoint-*.csv` files record the controls, analytical reference and nonlinear comparisons. `endpoint-snapshots.mat` is generated locally for reproducibility, not committed. The starting WVM head is `f09f2f5a187d8f218852b4c094b5c3465374137b` (open PR #380); the starting InternalModes head is `e7ea60dadc4e947769cda89f7c1116f22ffa404b`. The provider correction is committed as `cfd1a3b` on `audit/353-eigenproblem-equilibration`. This increment requires that correction, not merely the same API from an older release.

All 282 provider V2 cases are covered on final runtime code: 281 passed in the full run, and the one MDA assertion-scale correction passed its focused rerun. Coverage includes new high-resolution eigendepth/mode checks against analytical modes. WVM regression adds an end-to-end analytical finite-band endpoint check and exercises the short seasonal model, response assessments, diffusion integration and bottom friction. All 48 affected WVM cases pass, including wave/Boussinesq and independent diffusion qualification. Code Analyzer, documentation and source/artifact checks pass. The WVM documentation check reports 2358 files, 4819 routes and zero drift; the provider generated version history matches its changelog. Clean exported installs and the full WVM scientific CI graph remain #354; no package manifests, released snapshots or experiment files change here.

The next scientific increment is to revisit the intended-resolution, retained-band linear reference using the corrected provider and declared observable tolerances. Keep that distinct from this completed fixed-band conditioning diagnosis and from #367's long seasonal experiment.
