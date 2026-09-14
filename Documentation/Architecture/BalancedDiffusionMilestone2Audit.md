# Balanced diffusion 2: integration audit and revised sequence

Audited 13 September 2026 against `feature/v5.0-free-surface-qg` at `aed3c284075b62a5a4412bef13913beefb37c33d`, including the uncommitted, qualified T4 implementation described in [Issue435 validation](../Validation/Issue435/README.md). This is a local planning revision; it does not implement T5 or change hosted issues. The scope is [Balanced diffusion 2: Nonlinear model and restart](https://github.com/JeffreyEarly/wave-vortex-model/milestone/24), with [T5](https://github.com/JeffreyEarly/wave-vortex-model/issues/436) as the next increment. T4–T8 remain open in the hosted milestone at this audit date; local implementation and tracker completion are different states.

## Recommendation

Retain the existing peer transform hierarchy and milestone's scientific goals. The architecture is substantially aligned with the other transforms, but its remaining work should explicitly finish several shared interfaces before extending physics. Begin T5 with the energy/component corrections and the minimum diagnostic machinery needed to qualify drag. Complete the APV/thermal evolution adapter before T6 adds closure stability rules. Extend the existing stream reader in T8. No additional public transform, forcing base, integrator, observer, or persistence hierarchy is warranted.

The milestone already requires reuse, separate physical/source projection, complete thermal content, and restart through WVM. Those requirements are sound. Its ordering is less precise about common machinery: T5 and T6 require physical budgets that T7 formally delivers, while T7 repeats field work already done in T2. Pull the minimum shared inventory/rate interface forward, and leave comprehensive budget qualification in T7. Preserve the original acceptance criteria rather than replacing scientific work with interface tests.

## What should remain shared, and what should remain distinct

| Responsibility | Existing home and audit decision |
| --- | --- |
| Geometry and Fourier bookkeeping | Retain `WVGeometryDoublyPeriodic` and stratified geometry. Reuse physical wavenumbers, compact conjugate weights, horizontal differentiation and padded geometry. A thermal direction is never a substitute for APV mode number. |
| Coefficients, components, fields and cache lifecycle | Retain `WVTransform`, `WVCoefficientAnnotation`, `WVFlowComponent` and `WVOperation`. Discover actual families and shapes; do not infer them from `Nj`, legacy flags or `spectralMatrixSize`. |
| Scientific construction, reconstruction and weak duals | Retain peer implementations. APV/zero-APV inversion, thermal polynomial/weak projection, and Boussinesq wave/pressure/source projection represent different mathematics. Share a numerical helper only when its inputs and normalization are actually identical. |
| Physical forcing | Retain `WVSeasonalSurfaceAnomalyForcing`, `WVBottomFrictionQuadratic`, `WVNonlinearAdvection` and the existing forcing registry. The forcing owns its physical law and configuration; the transform owns conversion to its canonical families. |
| Time integration | Retain `WVModel`, `WVCoefficients`, `WVDensityDiffusionIntegrator` and the existing ETDRK4/controller/output lifecycle. Finish the small evolution adapter for the two QG representations. Boussinesq wave-phase dynamics do not acquire thermal diffusion semantics. |
| Inventories | Retain ordinary operations and the existing `quadraticDiagnostics` calling convention for QG peers. Share quadratic contractions and batched directional rates where useful; construct representation-specific metrics with all cross terms. Boussinesq's nonlinear moving-volume energy remains a distinct inventory. |
| Persistence | Retain annotated construction, `WVTransform.waveVortexTransformFromFile`, `initFromNetCDFFile`, forcing restoration, `WVModel.modelFromFile` and committed output groups. Concrete readers may remain thin wrappers; there is no reason for a second stream format. |

This follows the [shared v5 contracts](Issue355SharedContracts.md) and [T1 thermal design](Issue432ThermalTransform.md). The thermal peer's use of empty legacy F/G bootstrap arrays and explicit rejection of unsupported inherited operations is acceptable for this increment. Reorganizing the geometry hierarchy would enlarge the change without resolving the immediate interfaces.

## Findings requiring changes to the plan

### 1. Correct public energy normalization and component dispatch before drag budgets

The shared annotations in [`WVTransform`](../../@WVTransform/WVTransform.m) define `totalEnergy` and `totalEnergySpatiallyIntegrated` as horizontally averaged, depth-integrated energy per unit reference density, in m3 s-2. The APV QG and free-surface Boussinesq implementations honor that convention. In [`WVTransformFreeSurfaceThermalQG`](../../@WVTransformFreeSurfaceThermalQG/WVTransformFreeSurfaceThermalQG.m), `totalEnergy` instead returns depth-averaged energy, in m2 s-2; `totalEnergySpatiallyIntegrated` then multiplies by the entire volume. This is an actual public-interface mismatch, not a difference to preserve between representations.

Thermal also inherits `totalEnergyOfFlowComponent`, whose implementation examines legacy Ap/Am/A0 masks. A component selecting every Ath and Amda coefficient therefore returns zero. The existing [APV override](../../@WVTransformFreeSurfaceQG/totalEnergyOfFlowComponent.m) shows the correct pattern: select a family-keyed state, then evaluate its physical metric. Selected energies retain internal cross terms; energies of separate selections need not add to their union.

**T5 prerequisite:** multiply the current thermal depth-mean metric contraction by `Lz` for the public energy; make the spatially integrated property obey the same shared normalization, using an independent physical integral in validation. Implement the family-aware component path and correct the thermal property help. Preserve Ath units, all stored Gram arrays, eigenvector normalization and snapshots. Do not fix an API normalization error by renormalizing scientific state. T4's relative energy drift remains valid under this constant conversion; new absolute-energy and power comparisons must use the corrected convention.

### 2. Share the bottom-stress law, not the APV projection

[`WVBottomFrictionQuadratic`](../../Forcing/WVBottomFrictionQuadratic.m) already owns `Cd`, padded horizontal stress evaluation, configuration serialization and resolution conversion. Its free-surface path is currently APV-specific: it selects `QGSpectral` only for `WVTransformFreeSurfaceQG`, reads `kNonzero/lNonzero`, and obtains the bottom row through `phiHat` or `reconstructSpectralState`. Thermal lacks those APV convenience interfaces. Merely allowing the class in thermal registration will not make it work.

**T5:** keep this forcing class and its existing legacy hydrostatic/nonhydrostatic/barotropic behavior. Give both QG peers a narrow endpoint streamfunction hook returning one compact nonzero Fourier row, and implement the existing `boundaryMomentumTendency(tauXHat,tauYHat,endpoint)` signature on thermal. The stress has units m2 s-2 per unit density. Use shared `k(klNonzero)`/`l(klNonzero)` bookkeeping. The forcing applies `-Cd*speed*velocity` once; each transform performs its own balanced weak boundary projection. Derive the thermal load using its authoritative weak dual and endpoint test traces, never APV coefficient formulas or a fictitious top/bottom volume-cell force.

The existing [bottom-friction regression](../../UnitTests/TestFreeSurfaceQGBottomFriction.m) adds endpoint-weighted terms to physical energy before comparing work with the quadratic stress. It verifies generalized work for that signed APV projection. T5 must derive and report physical energy, enstrophy and any required endpoint/generalized work separately. An APV generalized-work pass does not establish thermal physical-energy dissipation. Preserve both active endpoints and check the projected response against the physical stress on independently refined horizontal quadrature. A doubled grid is the existing evaluation policy; the square-root speed law is not a finite quadratic polynomial whose aliasing error disappears automatically.

### 3. Finish the bounded evolution adapter already planned in T1/T3

Thermal [`linearEvolutionData`](../../@WVTransformFreeSurfaceThermalQG/linearEvolutionData.m) is implemented, but the corresponding APV adapter from the [T3 plan](Issue434ThermalIntegrationPlan.md) remains inside [`WVDensityDiffusionIntegrator`](../../Integrators/WVDensityDiffusionIntegrator.m). The controller is shared, which is good; packing, norm construction, configuration validation and explicit-RHS calls still branch on `thermalEvolution_`.

**Before T6:** extract the existing APV work into an internal adapter alongside the thermal adapter and have the controller consume one small contract. Select the adapter once at setup. Keep ownership unchanged: APV diffusion is owned by `WVVerticalDiffusivity`; thermal homogeneous diffusion is owned by the transform. The adapter supplies rates, family packing/unpacking, source projection, physical error norms and configuration validation. Bind the appropriate explicit-RHS invocation in the adapter instead of testing the concrete transform throughout the controller.

Preserve APV's four error components and departure-based relative scale, thermal's five components and total-state relative scale, all null rates, source exclusion, and rejection/output behavior. Represent these distinctions in adapter metadata/callbacks; do not silently homogenize scientifically different error policies. `thermalLinearDynamics` is an existing explicit compatibility option and need not be renamed in this milestone. Resolve registered advection by the actual validated forcing object, not solely its display name.

The current damping cap directly reads `WVAdaptiveDamping.dampAg_q/dampAg_0`. T6 must replace that dependency with a forcing-owned explicit stability bound in s-1 evaluated on the actual stage state. Preserve the present diagonal APV bound as its implementation. A mapped, potentially nonnormal thermal operator requires a justified bound for its action, not just an eigenvalue maximum or an APV-index array. Check all trial stages and retain the controller's rejection margin. Do not introduce a second timestep controller.

### 4. Keep one evaluation of each physical process and use it for diagnostics

T2 already provides the requested physical fields and ordinary operation lookup. T4 correctly keeps nonlinear product quadrature separate from native source sampling and projects nonlinear moments before reducing resolution. Preserve that distinction; a shared RHS must not route thermal advection through the native-grid APV product path.

There is unnecessary coupling in [`coefficientTendency`](../../@WVTransformFreeSurfaceThermalQG/coefficientTendency.m): it identifies forcing classes to decide whether to reconstruct native volumes, evaluates advection in advance, and passes a thermal coefficient tendency inside `physicalState.thermalNonlinearTendency` back through `WVNonlinearAdvection`. Adding drag under the current rule also requests a full native reconstruction even though drag needs only a bottom trace. The native tuple can separately recompute polynomial state for `phiHat`.

**T5:** use the endpoint hook for drag and keep native reconstruction lazy within the RHS. Evaluate thermal advection once and retain its tendency and speed as a local process result; accumulate it at the registered forcing position. Use the same evaluation worker for a direct advection diagnostic. Avoid carrying coefficient tendencies as physical fields. Preserve forcing order and exclusions. No persistent RK-stage cache or new public context class is needed.

Add an optional process breakdown to the existing family-keyed RHS, requested only by diagnostics. It must expose the same homogeneous diffusion, seasonal source, advection and drag contributions used in evolution; T6 adds separate horizontal/vertical damping. Preserve existing callback accumulation semantics: for an order-dependent callback, attribute its actual before/after increment instead of assuming it can be evaluated against a zero accumulator. Native sources can still share one projection in normal integration; pay for separate projected contributions only when budgets are requested.

Thermal's present forcing allowlist is an intentional qualification boundary, analogous to the Boussinesq inventory validator. Do not replace it with acceptance of every object carrying a broad `QGSpectral` label. Keep validated support in the existing constructor/atomic inventory hooks, extend it for the qualified drag, and check actual returned family names/shapes. A few concrete setup checks are clearer than a universal capability registry. MATLAB forcing compatibility must not accidentally advertise portable C++ support.

### 5. Bring the minimum T7 metric work forward and avoid duplicate budget machinery

The [APV `quadraticDiagnostics`](../../@WVTransformFreeSurfaceQG/quadraticDiagnostics.m) already accepts a state and a row of family-keyed tendencies, returns inventories, by-wavenumber contributions and horizontal means, and contracts several directional rates against one state. Reuse that public calling convention. Its contraction bookkeeping is reusable; its APV-only potential-enstrophy shortcut is not. Thermal enstrophy must use the full reconstructed QGPV metric, and endpoint and energy metrics must preserve nonorthogonal cross terms.

**T5:** implement only the energy/enstrophy/endpoint metrics and batched rate contractions required for forcing and drag qualification, using a shared private quadratic worker where both QG callers benefit. **T6:** extend those same process results for directional damping work. **T7:** complete operations, spectra, RMS/tails, generalized quantities that have an explicit scientific definition, and reconciled time-integrated budgets. This removes the incentive to build throwaway T5/T6 diagnostic implementations.

Share immutable physical reconstruction maps between thermal norms and metrics when their quadrature actually matches. Preserve the distinct nonlinear product quadrature and do not use a signed generalized metric as an error norm. Cache basis/metric products per immutable transform; coefficient/time changes invalidate field and process results. Changing diffusivity requires new rates and integrator attachment. Forcing conversion creates new objects owned by the target transform. `withDiffusivity` currently copies scientific/coefficient state and time, not the forcing inventory; keep that distinction explicit in examples and use the existing forcing-conversion hook when a configured run is transferred.

### 6. Complete the existing reader path; snapshot restoration is not model restart

The current thermal concrete reader permits only `iTime=1`, reconstructs root snapshot arrays and does not restore forcing. [`WVModel.modelFromFile`](../../@WVModel/modelFromFile.m) requests `iTime=Inf`, so the present reader cannot serve that lifecycle. This is the expected T8 gap, but it should be stated as a precise adapter task rather than a new I/O project.

**T8:** mirror the existing [Boussinesq reader](../../@WVTransformFreeSurfaceBoussinesq/waveVortexTransformFromFile.m): cheaply recover scientific state, call shared committed coefficient/time restoration, then call `initForcingFromNetCDFFile`; retain file ownership and failure cleanup. Adapt the thermal group constructor to accept scientific-only root state when time-dependent coefficients live in an observer group. Reuse WVCoefficients and existing complete-stream/committed-prefix selection. Preserve schema-1 linear-only migration and schema-2 nonlinear policy without repeating construction qualification.

No InternalModes/scientific mode solve is permitted on restoration. Rebuilding a numeric cache from a stored generator is distinct from reconstructing scientific modes: thermal integration currently diagonalizes its stored MDA generator on attachment. Make that lifecycle explicit and test attachment in the provider-unavailable continuation process. Never serialize transient handles or stage/departure buffers as canonical state.

T5 tests forcing configuration round trips and same-grid conversion through existing annotations. T8 owns spatial resampling of the seasonal Fourier pattern, physical resolution transfer, and full-model continuation. Preserve amplitude/period/phase and absolute clock; quantify pattern loss on coarsening or reject it. Do not infer correspondence between thermal directions by eigenvalue order. Newly constructed target representations may invoke scientific construction; restored targets may not.

## Revised increment boundaries

| Increment | Concrete deliverable | Finish gate |
| --- | --- | --- |
| T5, first change | Correct thermal energy and component semantics; minimum shared quadratic inventory/rate path | Independent depth integral, both public energy accessors, selected-state energy and polarization agree for nonzero mixed/mean states; existing APV/Boussinesq behavior preserved |
| T5, physical forcing | Reuse seasonal source and bottom-friction objects through selective endpoint reconstruction and thermal weak stress projection; one process evaluation/breakdown | Strict source units/clock/exclusion, signed stress and free-surface work, zero/finite Cd, source-only/drag-only/combined nonlinear time refinement, configuration round trips |
| Before T6 closure implementation | Finish the small two-owner evolution adapter | APV and thermal exact-source, tolerance, accepted/rejected-stage and output-cadence regressions preserve their existing behavior |
| T6 | Qualified named damping action using that adapter and the same process metrics | Explicit complement behavior, separate horizontal/vertical work and all-stage stability bound, manufactured equivalence where claimed, seasonal bias and developed-flow sensitivity |
| T7 | Complete the common QG diagnostic surface and process-budget qualification | Full metrics/cross terms/means, reconstructed directional rates, spectra and startup-aware integrated budget reconciliation |
| T8 | Thin annotated stream/forcing adapters and qualified physical transfer | Fresh-process full-physics restart without provider, committed-prefix recovery, independent output schedules, transfer loss and forcing clock/configuration |

The T6 closure choice is still a scientific decision. Start with the existing horizontal-wavenumber law and investigate the specified fixed APV projection/lift and complement. If vertical equivalence fails, name and persist a different closure rather than treating it as an alternate implementation of `WVAdaptiveDamping`. Share filter construction or stability plumbing where valid; do not require one class to hide different equations. Damping selection, full restart qualification and campaign performance remain downstream.

Extend `TestSharedResolvedContracts` to exercise the thermal peer alongside APV QG and the existing Boussinesq controls. In particular, test the same public energy units, component selection/polarization, named-field lookup and cache mutation on physically nonzero states. Keep APV bottom-friction/inventory tests, both QG exponential-integration suites, existing legacy forcing paths, and Boussinesq source/output tests as the focused compatibility gates for the corresponding edits. T8 adds thermal cases to committed-output/restart coverage. A separate thermal-only success suite would not detect the cross-transform mismatches found here.

## Proposed narrow interfaces

These are proposed additions/extensions, not claims about currently callable APIs. Keep existing signatures where they already express the responsibility.

```matlab
% Same endpoint convention and compact nonzero Fourier ordering on both QG peers.
psiHat = wvt.boundaryStreamfunction(endpoint); % proposed; row, m^2/s
dA = wvt.boundaryMomentumTendency(tauXHat,tauYHat,endpoint); % existing APV hook

% Extend the existing RHS only with an optional diagnostic result.
[dA,speed,processes] = wvt.coefficientTendency(...);
% processes contains labels and ordered family-keyed increments from this RHS.
[inventory,spectrum,meanPart] = wvt.quadraticDiagnostics( ...
    state=wvt.coefficientState(),tendency=processes.tendencies);

% Existing method on thermal; internal APV adapter supplies the same core data.
evolution = wvt.linearEvolutionData();
% Controller uses one adapter: rates, toModes, fromModes, physicalErrorNorms,
% projectSource, explicit RHS, configuration validation and error-scale policy.

% Proposed forcing hook, implemented only for supported explicit dissipation.
rate = force.maximumExplicitDampingRate(stageState); % s^-1, justified bound
```

Do not broaden Boussinesq `coefficientTendency`'s existing diagnostic result into this QG process structure as incidental T5 work. Share contractions below the public API where meaningful; nonlinear Boussinesq energy and source coordinates need their own contracts. Keep legacy three-array transforms' supported forcing paths unchanged.

## Compatibility and verification ledger

Read-only inspection covered hosted T5–T8 issue bodies and milestone 24, the T1/T3/T4 plans, shared v5 contracts, all three free-surface peers, the legacy forcing paths, diffusion integration, diagnostics, annotated readers and focused tests. Hosted issue bodies still contain older September 9 baseline notes; implementation should identify the actual feature-branch commit and retain their scientific constraints. Dependency snapshots and experiment pins remain unchanged.

A bounded MATLAB probe used a constant N2=1e-4 s-2 thermal state, domain 100 km by 100 km by 1000 m, grid 4 by 4 by 65, 17 thermal directions and 4 MDA modes, with one nonzero Fourier column and Legendre pressure coefficients `[10;10;2]`. It reconstructed velocity, total displacement and SSH and integrated physical energy with native depth weights. This manufactured polynomial is sufficient to distinguish normalization factors; it is not a new thermal accuracy qualification.

| Audit probe | Observed result |
| --- | --- |
| Independent horizontally averaged depth integral | `5.454749059694578e-4 m3 s-2` |
| Current thermal `totalEnergy` | `5.454749059694577e-7`; independent integral/current value = `1000 = Lz` |
| Current `totalEnergySpatiallyIntegrated` | `5.454749059694577e6`; current value/independent integral = `1e10 = Lx*Ly` |
| Component selecting Ath and Amda | `totalEnergyOfFlowComponent = 0` for the same nonzero state |
| Snapshot with one seasonal forcing and time 1234 s | Time restored to 1234 s; forcing count changed from 1 to 0 |

The initial probe stopped at the exclusive-provider guard: `restoredefaultpath` plus snapshot setup still left the older sibling `internal-modes-evp` visible. The corrected run removed sibling InternalModes paths after `configureCIEnvironment` and verified unique `IMInternalModes` resolution inside `OceanKit/InternalModes-2.0.0-beta.4`. The intended provider remains tag `v2.0.0-beta.4`, revision `f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`. Other loaded snapshots were Distributions 2.0.0, SplineCore 2.2.0, chebfun 5.7.0, NetCDF 1.0.2 and ClassAnnotations 1.2.1. This was an environment guard failure, not scientific evidence from the wrong provider.

Probe command: `matlab -batch "run('/private/tmp/auditThermalMilestone.m')"`; corrected output: `/tmp/thermal-milestone-audit-clean.log`. These temporary files support this audit; the measured findings and state definition above are retained here. Run MATLAB outside the local macOS sandbox. Add regression tests for these currently failing contracts in the T5 correction; the audit itself changes no MATLAB source/tests and does not duplicate the already-passing 47 T4 focused tests or rerun seasonal qualification.

Final verification: `matlab -batch "run('/tmp/thermalAuditDocs.m')"` ran clean snapshot setup with ClassDocumentation 1.3.2 and `buildtool docs:check`: 2621 files, 5347 routes, zero validation failures and zero generated differences. The initial documentation launcher had an invalid hyphenated MATLAB script name and stopped before running the check; renaming that temporary script resolved it. The successful check ran once. Relative-link checks passed for all 18 links across this audit and the updated T4 plan; `git diff --check` and added-file whitespace checks passed. Scope review found only this new audit and the appended T4-plan cross-reference as audit edits; no package manifest, website source, runtime or test changes were made. Code Analyzer and scientific regression reruns are not needed for these planning-only edits.

No gate remains blocked and no scientific assets are required or missing for this audit. The pre-existing T4 changes, generated documentation, released package snapshots, experiment repository and unrelated local study are preserved.
