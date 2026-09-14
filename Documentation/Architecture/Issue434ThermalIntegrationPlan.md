# T3: Thermal evolution through WVModel

Status: implementation plan for [#434](https://github.com/JeffreyEarly/wave-vortex-model/issues/434), following the completed [T2 construction and evidence](../Validation/Issue433/README.md). T3 is planned, not implemented. Use the T2 commit containing this plan on `feature/v5.0-free-surface-qg`; record its exact hash at implementation start. Preserve InternalModes `v2.0.0-beta.4` (`f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`) and all installed dependency snapshots and experiment pins.

## Outcome and scope

A `WVTransformFreeSurfaceThermalQG` with registered strict seasonal forcing must evolve through `WVModel.setupIntegrator(integratorType="exponential")` using the existing exact harmonic response, ETDRK4 controller, accepted-state lifecycle and observation scheduling. Public coefficients always hold instantaneous physical state. T3 qualifies linear physics and general explicit-stage integration machinery. T4 supplies nonlinear QG products; T5 completes physical forcing/drag parity; T6 supplies closure; T8 qualifies full restart.

Do not use `shouldUseLinearDynamics=true` as the switch for this problem: its existing analytical-phase semantics do not describe forced diffusion. Expose an explicit supported thermal linear configuration that omits the unimplemented nonlinear callback while still evaluating diffusion and registered sources. Do not silently make general thermal dynamics linear.

## Implementation sequence

1. **Establish the evolution adapter.** Implement the T1 `linearEvolutionData()` contract with `familyNames`, `familyShapes`, `rates`, `toModes`, `fromModes`, `physicalNormFactors`, and `projectSource`. Keep Ath unchanged in modal packing; diagonalize the stored conservative MDA generator into transient integration coordinates, validate its inverse/residual and real-state recovery, and retain null directions. Derive rates from the unit-diffusivity arrays multiplied by `kappa_z` exactly once, including zero. No scientific basis reconstruction is allowed during attachment. Build the corresponding APV adapter around its existing diffusion-forcing-owned operators.
2. **Adapt the existing integrator.** Replace concrete APV assumptions in `WVDensityDiffusionIntegrator` constructor, `modalState`, `setModalState`, `toModes`, `fromModes`, configuration validation and norm construction. Use generic coefficient state access. Preserve the controller, full/two-half steps, harmonic integral, `WVInternal.exponentialRK4Step`, rejected-stage restoration and output sampling. Retain APV diffusion registration semantics and its existing tolerance behavior. Cache exponential factors by step size and unique rates where applicable; keep dense reconstruction caches separate.
3. **Connect forcing and RHS ownership.** Permit `WVSeasonalSurfaceAnomalyForcing` on the thermal peer using its existing strict physical source projection, both endpoint dimensions and zero-mean checks. The forcing owns amplitude, period, phase, pattern and absolute clock. Thermal registration rejects `WVVerticalDiffusivity`: the transform owns homogeneous diffusion. Add an explicit exclusion for transform-owned homogeneous evolution when computing exponential stages; do not disguise it as a registered forcing. Exclude the analytic seasonal source from explicit stages as well. A supported ordinary RHS must apply both exactly once; otherwise reject that path explicitly. Permit bounded manufactured explicit forcings for ETDRK4 tests without claiming nonlinear physics or bottom-stress support.
4. **Supply physical error control.** Build weighted reconstruction/QR factors from authoritative thermal maps and MDA maps. Include compact Fourier pair weights and all nonorthogonal cross terms. Assess QGPV, buoyancy and speed, with surface and bottom displacement separately; add thermal-specific norm metadata/tolerance mapping without changing APV defaults. The full positive physical-energy norm is also a scientific acceptance observable. Never use Euclidean Ath magnitude as physical energy. Preserve CFL and explicit-damping-cap hooks; reject unsupported closures instead of applying APV-index tapers to Ath.
5. **Qualify the actual model.** Add focused thermal integration tests and extend the bounded qualification utility to drive the actual transform/model. Preserve the independent research reference and the T2 construction CSVs. Save integration evidence separately, including construction settings, accepted/rejected steps and physical residuals.

Changes should remain concentrated in the thermal peer, narrow APV adapter code, the existing integrator, seasonal-forcing compatibility, necessary WVModel dispatch, focused tests and evidence. No second integrator facade or copied controller.

## Verification gates

| Control | Required evidence |
| --- | --- |
| Exact homogeneous/seasonal evolution | Independent augmented-matrix exponential or analytic solutions at zero/tiny time, null rates, zero forcing, zero diffusivity, changed phase, nonzero start time and complex Fourier coefficients |
| Mean evolution | Signed nonzero Amda, conservative column inventory, reality and zero-diffusion identity |
| Ownership | Homogeneous and harmonic terms applied once in every supported RHS path; duplicate diffusion registration rejects; changed diffusivity requires a new transform/attachment; forcing replacement refreshes source caches |
| Explicit ETDRK4 | Manufactured state-dependent residual, independent reference, genuine accepted-step refinement as tolerance tightens, and actual rejection/failure restoring accepted coefficients and time |
| Observations | Vary observation cadence without changing accepted steps/states where the existing output contract promises it; exact final-time semantics |
| Seasonal science | All 30 observable/time checks at 257 and 385 directions; preserve the 129-direction failure; separate integration error from representation error |
| Independent controls | Refined physical-depth reference and fixed-space assembly refinement, each within one fifth of observable allowances |
| Compatibility | Existing APV density-forcing/exponential tests and shared coefficient/cache regressions pass |

The seasonal case retains depth 4000 m, latitude 24 degrees, N2=(5.2e-3)^2 exp(2z/1300), diffusivity 1e-5 m2/s, annual mode-5 meridional forcing in a 500 km domain, both active endpoints and insulating diffusion. Use days 1, 8, 32, 64 and 91.3125. A reduced single-harmonic geometry may provide a bounded linear control only if the physical wavevector and amplitude equivalence are explicitly verified.

Retain the issue's RMS allowances: QGPV 1e-13 s^-1 plus 5% of reference; buoyancy 1e-10 m/s^2 plus 0.1%; SSH 1e-8 m plus 0.01%; each endpoint 1e-8 m plus 0.1%; positive physical-energy state norm 0.01%. These are case-specific acceptance criteria, not new public defaults. Equal cap-limited steps at two tolerances do not demonstrate adaptive convergence.

Run clean snapshot setup with `configureCIEnvironment`, verify unique beta.4 symbol resolution, run focused tests and scientific controls, Code Analyzer on changed MATLAB files, one coherent documentation generation/check cycle if canonical API documentation changes, runtime-layout and whitespace/scope checks. Record commands, exact commits, pass/fail measurements, warnings and blocked checks in a T3 validation report. Do not rerun successful gates without a relevant subsequent change.

## Handoff boundary

Completion means the actual WVModel path reproduces the qualified linear response and the shared explicit integration machinery is tested. It does not mean nonlinear evolution, damping selection, full stream restart, campaign throughput or long-run readiness is qualified. No experiment migration, release, snapshot update or production seasonal campaign belongs to T3.
