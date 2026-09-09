# Resolved mixed-state free-surface Boussinesq transform

This increment of #366 implements `WVTransformFreeSurfaceBoussinesq`, a peer of free-surface QG. It reconstructs and projects pure and mixed wave/balanced states and advances their exact linear phases through the shared state, operation, component, and cache contracts. Source-driven `WVModel` integration and annotated file continuation remain the next increment; this does not close #366 or #355.

## Construction and public interfaces

```matlab
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65], ...
    N2Function=@(z)1e-4*exp(2*z/700), ...
    waveModeCount=4,apvModeCount=3,mdaModeCount=2,inertialModeCount=3);
wvt.Aw_p(1,1) = .01;
wvt.Ag_q(1,1) = 1e-8;
wvt.Ag_0(:,1) = 1e-8*[1;2];
wvt.t = 1234;
fields = wvt.reconstructFields(["u","v","w","eta","p","ssh"]);
[coefficients,assessment] = wvt.projectFields(fields);
assessment.relativeFieldEnergyError
wvt.physicalEnergy()
copy = WVTransformFreeSurfaceBoussinesq(wvt.scientificState());
```

`fromStratification` performs scientific construction. The primary constructor accepts the complete flat geometry/operator structure returned by `scientificState()` and performs no new scientific solve; coefficients and time are set separately. Stored operator arrays are read-only. The in-memory constructor is tested, while file writers explicitly reject unqualified persistence instead of falling through to a rigid-lid reconstruction path.

| Family | Stored coefficient shape | Meaning and time convention |
| --- | --- | --- |
| `Aw_p`, `Aw_m` | waveMode × klNonzero | Positive/negative frequency amplitudes in m/s at `t0`; multiply by exp(±iω(t−t0)) |
| `Ag_q` | apvMode × klNonzero | Generalized-energy APV coefficients in s⁻¹; stationary |
| `Ag_0` | activeEndpoint × klNonzero | Boundary-normalized zero-APV coefficients in s⁻¹; stationary |
| `Aio` | inertialMode × 1 | One complex coefficient per inertial mode, in m/s; multiply by exp(if(t−t0)) |
| `Amda` | mdaMode × 1 | Real mean-displacement coefficients in meters; stationary |

A Fourier nonzero column represents one Hermitian half-plane amplitude plus its conjugate. The horizontal mean already includes both conjugates for inertial oscillations and occurs once for MDA. The inherited `Nj` describes the APV geometry only; it is not a wave, inertial, or MDA count. Explicit counts select strict prefixes of the provider's resolved modes; failed grid qualification never silently changes the requested count.

Supported physical fields are `u`, `v`, `w`, `eta`, `eta_i`, `p`, `ssh`, `ssu`, `ssv`, and `qgpv`. `eta` is total displacement and `eta_i = eta-(1+z/Lz)*ssh`. Pressure includes MDA hydrostatic pressure with zero surface gauge. Mean SSH is zero. Operations and direct access use the same reconstruction as `reconstructFields`; registered components are `wave`, `apv`, `zeroapv`, `balanced`, `inertial`, and `mda`. Here `balanced` includes both geostrophic families and MDA. Component selection uses the shared independent-family masks. These are selectors, not a claim that legacy random-amplitude and primary-mode enumeration APIs have been ported.

## Scientific projection

At nonzero horizontal wavenumber, projection follows the manuscript's observable-state sequence:

1. Compute APV from `ik*v-il*u-f*Dz*eta`, and project it using the existing APV F Galerkin matrix.
2. Form the active endpoint anomalies `[eta(surface)-ssh; eta(bottom)]`, subtract the reconstructed APV endpoint response, and recover the boundary-normalized zero-APV coefficients.
3. Reconstruct the balanced displacement from those coefficients, then project vertical velocity and the remaining displacement into the wave families.

Writing the retained wave functional as

$$\mathcal G_j[b]=\frac{1}{g}\int_{-D}^{0}(N^2-f^2)G_jb\,dz+G_j(0)b(0),$$

the wave coefficients at `t0` are

$$A_{w,\sigma}^j=\frac{e^{-i\sigma\omega_j(t-t_0)}}{2\kappa h_j}\left(i\mathcal G_j[w]-\sigma\omega_j\mathcal G_j[\eta-\eta_g]\right).$$

Horizontal-mean velocity uses the inertial F projection of `(u-iv)/2` and removes its reference-time phase. Mean displacement uses the existing signed MDA Galerkin projection. The inertial F modes come from the free-surface fixed-wavenumber problem at κ=0, where their continuous F norm is h. MDA pressure is obtained from its stored hydrostatic F mode after subtracting the surface constant.

The APV/MDA matrices retain the existing provider's signed Galerkin treatment of the sampled Gram matrix. The wave and inertial matrices apply the continuous-normalization functionals with the fixed quadrature, without Gram correction. Both use the original resolved modes; neither replaces their basis with a fitted collocation space. `projectFields` is an admissible-state observable projector, not yet a generic forcing/source projector.

`assessment.relativeFieldEnergyError` measures the positive-energy norm of input fields minus their resolved reconstruction, on the selected grid. It reports a sampled-state representation residual, not a certificate for unresolved input structure or continuous-profile accuracy. Per-family Gram errors and continuity/boundary diagnostics accompany it.

## Retained design and shared changes

The transform retains `WVGeometryDoublyPeriodicStratified`, the compact Fourier geometry, stratification/rotation roles, `WVTransform`, `WVCoefficientAnnotation`, `WVOperation`, and `WVFlowComponent`. The existing free-surface balanced scientific builder and its resolution-assessment helpers move to `+WVInternal`; QG and the new transform call the same functions. The peer uses explicit independent retained counts while QG retains its existing automatic selection behavior and public error identifiers.

The legacy wave/geostrophic/inertial/MDA mixin initializers assume `Ap/Am/A0`, common `Nj` allocations, and rigid-lid or primary-component formulas. They remain intact for existing transforms. Inheriting those initializers unchanged would install the wrong operators in this peer. The new transform instead retains their physical-family separation and uses the qualified free-surface polarization helper plus shared annotation/component machinery. Further shared extraction should follow demonstrated source/integration needs rather than a generic hierarchy rewrite.

Coefficient changes invalidate registered physical fields. Time changes invalidate wave/inertial-dependent fields while stationary selected-component caches survive. Changing `t0` now invokes the base class's existing time-dependent cache invalidation, fixing a missing reference-time invalidation for both new and legacy wave transforms. Scientific operators remain unchanged across all these mutations.

Positive physical energy is

$$E=\frac12\left\langle\int_{-D}^{0}(u^2+v^2+w^2+N^2\eta^2)\,dz+g\zeta^2\right\rangle_{xy}.$$

The Fourier implementation is checked against explicit real-space quadrature. It includes all cross terms within a selected state. APV and zero-APV self energies do not sum to their combined physical energy. Generalized signed energy is not used as the error norm.

## Qualification and quantitative results

Parameters: 100 km × 100 km × 1000 m domain, 8 × 8 horizontal grid with the existing antialiasing rule, latitude 30°, rotation rate `7.2921e-5 s^-1`, gravity `9.81 m s^-2`, density `1025 kg m^-3`. Profiles are `N2=1e-4` and `N2=1e-4*exp(2*z/700)` in s⁻². The default balanced endpoints are both active: `g0=-integral(N2)` and `gd=+integral(N2)`. All retained horizontal columns participate in the mixed-state fixtures.

Each case retains 4 modes per wave sign, 3 APV modes, 2 endpoint modes, 3 inertial modes, and 2 MDA modes. Wave/inertial EVP resolution is 64 coefficients. Balanced construction retains the QG policy `max(96,3*(Nz+4))`, giving 111 and 207 coefficients for the accepted 33- and 65-point grids. Thus the sampling sweep also changes the balanced solve's numerical resolution, but never the retained family counts. Both resolutions are recorded in the CSV.

In this historical qualification, the 17-point grid was rejected for both profiles at the then-default normalized-Gram tolerance of `1e-7` (the current API uses `gramTolerance`): maximum wave/inertial Gram errors are `2.17e-7` and `2.11e-7`. Those rejections are recorded explicitly. For accepted grids, the table gives maxima over both profiles, every pure family and the mixed state, and times 0, 1234, and 100000 s:

| Vertical samples | Field-energy projection error | Family coefficient-energy error | Continuity residual | Relative energy variation |
| ---: | ---: | ---: | ---: | ---: |
| 33 | 3.13e-11 | 3.14e-11 | 2.12e-12 | 1.43e-11 |
| 65 | 2.08e-10 | 2.39e-10 | 3.67e-13 | 1.43e-11 |

The mixed-state field-energy errors alone remain below `1.64e-11`. Fourier energy agrees with explicit physical-field quadrature to `5.40e-15` relative across the accepted cases. Higher resolution is not uniformly more accurate at this small retained band; the balanced solve's increased numerical resolution also contributes to the observed roundoff sensitivity.

Field error is the square root of residual physical energy divided by input energy. The coefficient error sums the positive physical error energy of each family separately before taking a square root; errors in different families cannot cancel this check. Continuity uses the Frobenius residual divided by the sum of the three separate derivative-term norms, avoiding a misleading unit residual when geostrophic horizontal terms cancel. Time variation uses exact modal phases, not a time integrator.

The seven new tests also check the full linear horizontal and vertical momentum equations, displacement evolution, APV, bottom impermeability, surface kinematics, dynamic surface pressure, pressure's MDA gauge, ordinary field access, all component operations, reference-time phases, cache behavior, and direct canonical construction. Additional controls use negative latitude and one/no active endpoints. The bounded equation tests use termwise relative norms, with `2e-6` for vertical momentum and `1e-7` for horizontal momentum, continuity, and surface kinematics. These are explicit regression bounds, not universal model-accuracy guarantees.

Run `TestFreeSurfaceBoussinesqTransform.runStudy('Documentation/Validation/issue-366-mixed-transform.csv')` to reproduce the 84 accepted case/time rows and two construction rejections. The earlier wave-only analytical/ODE-reference study remains in `Issue366FreeSurfaceWaveQualification.md` and continues to pass.

Verification: 7 new tests and 129 affected existing tests passed on MATLAB R2025b Update 4, including QG construction/resolution assessment, vertical calculus, diagnostics/conservation, density forcing, integrators/output/restart, existing wave validation, legacy components, and operation registration. Focused tests were rerun after the final cache/error-norm/component-registration corrections. Production Code Analyzer has no blocking findings; two new performance advisories concern annotation-array growth during setup. Documentation build/check passed with 2357 files and 4817 routes and no generated drift. The new experimental API is documented in source and this handoff; adding it to the supported website catalog is deferred. No task assets were missing.

Provenance: WVM integration baseline `08992b9d4b8ffde7c55ef6bb6b9ace598e5db7b8`; corrected InternalModes authoring provider `e7ea60dadc4e947769cda89f7c1116f22ffa404b`; manuscript `ape-apv-free-surface/main.tex` at `0a2edf4199aed1a195778c2ae66dea41118c9265`, especially the linear solution, observable wave projection, endpoint projection, and horizontal-mean projection equations. Package metadata and released snapshots are unchanged. Hosted smoke CI still uses an older provider snapshot and does not qualify these full-tagged v5 tests; released graph and CI adoption remain in #354.

## Next increment

Add a controlled linear source with the manuscript's generic source semantics, advance it through the existing `WVModel`/coefficient tendency and integrator paths, then qualify uninterrupted versus stored-state continuation using the stored scientific operators. Reuse annotated persistence rather than introducing a second file format. #352 owns broader output and resolution-transfer coverage. This increment provides no qualified nonlinear flux, arbitrary-source projection, file restart, resolution transfer, legacy random-mode initialization, or full primary-component enumeration.

## Subsequent forced-evolution increment

The source, model-integration, and annotated restart gaps described above are now exercised by `Issue366ForcedBoussinesqEvolution.md`. It adds the model-specific volume-source projector, a persistent controlled source, fixed-step model evolution, and operator-based file continuation. The original transform-only evidence and its scope remain recorded above.
