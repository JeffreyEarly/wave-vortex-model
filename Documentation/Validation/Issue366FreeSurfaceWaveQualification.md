# Free-surface wave validation for #366

This completes the wave-only scientific validation stage, not the full linear Boussinesq model. Six resolved modes per frequency sign, including the external surface-gravity mode, reconstruct velocity, pressure, total displacement, and sea-surface height consistently with the manuscript. The implementation is `WVInternal.freeSurfaceWavePolarization`; the reproducible experiment is `TestFreeSurfaceWaveModes.runStudy`.

## Provider defects exposed by the validation

1. `IMInternalModes.innerProduct` used `N2/g` for every G-mode normalization. The fixed-wavenumber eigenproblem instead has weight `(N2-f0^2)/g`; the fixed-frequency problem has `(N2-omega^2)/g`. Solved G modes now use their canonical EVP weight. The positive majorant takes the absolute interior weight as well as absolute endpoint coefficients. Hydrostatic diagnostic products and F-mode normalization retain their existing conventions.
2. `IMSolverSpectral` constructed stretched coordinates with `cumtrapz`, inverted/interpolated them with separate PCHIP maps, evaluated the first derivative from the original stratification, and approximated its derivative with `gradient`. These were inconsistent representations of one coordinate. The solver now represents the coordinate derivative with Chebfun, integrates and differentiates that representation, and inverts the same map with bounded bisection. Dedicated derived properties are rebuilt on configuration; no canonical prognostic state is changed or cached there.

Before the first correction, the constant-stratification normalization defect was approximately `1e-4` for `N2=1e-4` and `f0=1e-4`, consistent with the missing `f0^2/N2` factor. After normalization was corrected but before the coordinate correction, the exponential-profile long-wave vertical-momentum residual reached `5.62e-4` at 128 EVP coefficients and 129 sample points. With consistent coordinates, the same case reached `1.64e-6`; using 64 EVP coefficients for the same six retained modes reduced it further to `1.22e-7`. The remaining pressure-derivative sensitivity is documented below rather than hidden by renormalizing the fields or changing the resolved basis.

Both provider corrections are in [InternalModes PR #15](https://github.com/JeffreyEarly/internal-modes/pull/15), commit `0e53285`. This validation requires that corrected authoring version; it is not clean-install evidence for the existing released dependency floor. #354 must release/export the corrected provider before qualifying the released consumer graph.

## Scientific contract

For nonzero horizontal wavenumber magnitude $\kappa$, the retained functions satisfy

$$G_j''-\kappa^2G_j=-\frac{N^2-f^2}{g h_j}G_j,\qquad F_j=h_jG_j',\qquad G_j(-D)=0,\qquad G_j(0)=F_j(0),$$

with $\omega_j^2=f^2+g h_j\kappa^2$ and normalization

$$\frac1g\int_{-D}^0(N^2-f^2)G_iG_j\,dz+G_i(0)G_j(0)=\delta_{ij}.$$

Polarizations use the manuscript's `linear-solutions-wave-state-vector` and time convention $\exp(i\sigma\omega_j t)$, with pages ordered $\sigma=[+1,-1]$. A real physical field is the half-complex field plus its complex conjugate. Consequently, a mode with complex velocity amplitude $A_j$ has positive physical energy $2h_j|A_j|^2$ per unit reference density. The factor of two is verified with explicit horizontally sampled real fields.

The tests apply the five linear equations directly to reconstructed fields using sampled physical-coordinate differentiation. They check horizontal and vertical momentum, incompressibility, total-displacement evolution, zero linear APV, bottom impermeability, and the dynamic and kinematic surface conditions. Pressure is compared with `rho0*g*eta(surface)`; the independently defined SSH comes from surface pressure. Interior fields are

$$\eta_i=\eta-(1+z/D)\zeta,\qquad w_i=w-(1+z/D)\partial_t\zeta,$$

and vanish at both endpoints for these waves. A shared sampling grid never replaces the resolved modal basis.

## Parameters and independent references

- Depth: 1000 m; `f=1e-4 s^-1`; `g=9.81 m s^-2`; `rho0=1025 kg m^-3`.
- Constant profile: `N2=1e-4 s^-2`. Variable profile: `N2=1e-4*exp(2*z/700) s^-2`. Both satisfy `N2>f^2` throughout the domain.
- Horizontal wavelengths: 100, 10, and 1 km; `k=.6*kappa`, `l=.8*kappa`, so both horizontal components are exercised.
- Constant stratification also includes exactly `kappa=sqrt((N0^2-f^2)/(g*D))`, where the external mode changes from an oscillatory vertical function to a hyperbolic one and is linear in z at the transition. The reference includes all three cases.
- Six modes per sign are retained throughout. Provider labels are 1 through 6; their interior node counts are 0 through 5. Endpoint-clustered reference samples resolve internal nodes very close to the free surface.
- Primary EVP resolution: 64 coefficients. Independent WKB-Chebyshev sampling grids have 17, 33, 65, or 129 points. A separate EVP sweep uses 32, 64, and 128 coefficients without changing the retained count.
- Constant-stratification references solve the scalar trigonometric/hyperbolic dispersion relations and use closed-form normalization integrals. They do not use a matrix eigenvalue solve.
- Variable-stratification references integrate the physical-z second-order ODE with `ode113` and solve the surface residual with `fzero`. Root brackets are ±0.05 in log h around the spectral estimates; nodal counts verify their family ordering. This is an independent local root/refinement check, not an independent global search for every eigenvalue. Relative ODE tolerances are `3e-10` and `3e-12`, with absolute tolerances one hundred times smaller; normalization uses 256-point physical Gauss quadrature. The largest frequency change between those reference tolerances is `9.69e-11` relative.

## Results and norms

The following are maxima across all seven profile/wavenumber cases, with 64 EVP coefficients and six modes per sign.

| Sample points | Positive-energy Gram error | Modal projection error | Energy variation under exact phase evolution | Vertical-momentum residual |
| ---: | ---: | ---: | ---: | ---: |
| 17 | 1.38e-4 | 4.23e-5 | 2.23e-5 | 1.09e-4 |
| 33 | 2.65e-11 | 8.58e-12 | 3.26e-12 | 4.98e-8 |
| 65 | 2.65e-11 | 7.95e-12 | 3.10e-12 | 1.17e-7 |
| 129 | 2.65e-11 | 7.95e-12 | 3.10e-12 | 1.22e-7 |

At 129 sample points, frequency agreement with the fine reference is `3.40e-12` relative and single-mode field agreement is `2.42e-11` in the positive physical-energy norm. These are reference agreements, not certified absolute errors; the independent reference refinement difference above is also reported. Incompressibility is below `2.09e-13`, APV below `5.22e-14`, and surface/interior endpoint residuals below `6.64e-12` in their stated relative norms.

Field errors use the square root of volume kinetic plus displacement potential energy and surface gravitational energy, after aligning each reference mode's arbitrary sign. The energy Gram error is the matrix 2-norm after normalizing each polarization by `sqrt(2*h)`. Projection error uses the same positive coefficient-energy norm. Equation residuals use quadrature-weighted L2 norms divided by the sum of the norms of that equation's terms, per mode and sign; endpoint residuals use the relevant field-amplitude scales. Pressure has no independent contribution to the energy norm, so its derivative is checked explicitly. Energy variation compares exact modal phases at 0, 1000, and 100000 seconds; it does not test a time integrator.

Increasing EVP resolution does not monotonically improve this small retained band:

| EVP coefficients, 129 sample points | Frequency agreement | Field agreement | Vertical-momentum residual |
| ---: | ---: | ---: | ---: |
| 32 | 1.14e-11 | 1.99e-11 | 3.09e-8 |
| 64 | 3.40e-12 | 2.42e-11 | 1.22e-7 |
| 128 | 1.77e-10 | 4.87e-10 | 1.64e-6 |

High-order differentiation amplifies eigenvector roundoff, particularly for the long external mode. The tests use a `2e-7` vertical-momentum bound for the qualified 64-coefficient band; other equation/endpoint bounds are `1e-7`, and normalization, projection, and energy bounds are `1e-8`. These are explicit regression bounds for the listed cases, not a universal resolution threshold. Do not choose the largest possible EVP size merely because it is available.

## Reproduction and provenance

Run on the corrected authoring dependency graph, with `UnitTests` on the MATLAB path:

```matlab
[summary,modes] = TestFreeSurfaceWaveModes.runStudy('Documentation/Validation');
[sweep32,~] = TestFreeSurfaceWaveModes.runStudy('',nEVP=32);
[sweep128,~] = TestFreeSurfaceWaveModes.runStudy('',nEVP=128);
writetable([sweep32;summary;sweep128], ...
    'Documentation/Validation/issue-366-wave-evp-resolution.csv');
```

The committed CSV files record every case/grid and per-mode h, frequencies, reference refinement, labels, and node counts. Manuscript source: `literature/ape-apv-free-surface/main.tex` at `0a2edf4199aed1a195778c2ae66dea41118c9265`, especially `linear-equations`, `linear-boundary-conditions`, `linear-total-displacement`, and the wave solution/normalization equations. WVM baseline: `0815dcd7`; InternalModes baseline before the corrections: `9e2edb3eda96191078e22f5d3a8bc785be38143d`. Execution: MATLAB R2025b Update 4 on Apple Silicon.

Verification: all 281 InternalModes V2 tests and 74 affected WVM tests passed. The latter include the new wave checks, shared component contracts, QG diagnostics/conservation, forcing, ordinary/exponential integration, output, and restart. WVM documentation consistency and production analyzer passed; provider documentation was regenerated. The modified provider solver retains one pre-existing unused-input analyzer advisory. Ten directly affected tests passed again after the final local-variable cleanup. No task asset was missing.

Hosted WVM CI currently loads the pinned `InternalModes-1.3.0` OceanKit snapshot and runs the smoke gate on integration-branch pull requests. It does not execute these full-tagged wave tests against the corrected provider. The results above are local authoring-graph evidence; #354 must update and qualify the released dependency graph and its CI coverage before release.

## Remaining #366 work

Build the peer free-surface Boussinesq transform around these stored resolved polarizations and the qualified balanced families. Exercise independent family counts through shared state/operation/component contracts; establish the mixed wave/balanced projection and positive physical-energy accounting; then add a controlled linear source, integrator evolution, and stored-state continuation. The present projection experiment covers the wave family only. It does not establish wave/balanced orthogonality on a chosen shared grid, mixed-family projection, full model persistence, or nonlinear dynamics. Keep #366 and #355 open; #352 owns the broader transfer/persistence matrix.
