# Shared resolved-mode contracts for v5

Status: shared interfaces are merged; the peer free-surface Boussinesq mixed-state transform is implemented in the next #366 increment. Source-driven integration and stored-state continuation remain before these contracts are frozen. Original comparison baseline: `e1b217b4`; mixed-state increment baseline: `08992b9d` on `feature/v5.0-free-surface-qg`.

## Retain the hierarchy

The existing hierarchy separates numerical geometry, model equations, physical solution families, and lifecycle machinery. Multiple inheritance is serving useful purposes; replacing it with a single generic transform would mix responsibilities that are currently separate.

| Responsibility | Existing Boussinesq implementation | Free-surface QG implementation | Decision |
| --- | --- | --- | --- |
| Horizontal layout, Fourier transforms, quadrature | `WVGeometryDoublyPeriodic` and stratified descendants | Same geometry lineage | Retain shared geometry and compact Hermitian bookkeeping. |
| Stratification and modal setup | `WVStratification`, including the rigid-lid `verticalProjectionOperatorsForIGWModes` path | Canonical scientific state built with InternalModes EVP providers | Retain profile and geometry abstractions; boundary-specific setup cannot be inherited unchanged. |
| Vertical resolved modes | `WVGeometryDoublyPeriodicStratifiedBoussinesq`: wavenumber-dependent wave matrices and geostrophic matrices | Stored APV, zero-APV, and MDA bases on one physical grid | Keep scientific operators model-specific. A sampled grid does not determine the number of retained modes. |
| Physical solution families | `WVGeostrophicMethods`, `WVInternalGravityWaveMethods`, `WVInertialOscillationMethods`, `WVMeanDensityAnomalyMethods` | Separate canonical families and endpoint inversion | Retain the mixins and analytical primary-mode enumeration. Do not make QG inherit rigid-lid initialization formulas. |
| Coefficient state | `Ap`, `Am`, `A0`; reference-time wave phases; MDA occupies zero-horizontal-wavenumber `A0` | `Ag_q`, `Ag_0`, real `Amda`, independent dimensions, omitted inactive endpoints | Discover families through existing `WVCoefficientAnnotation`; add family-keyed selection to shared infrastructure. |
| Fields and components | `WVOperation`, `WVFlowComponent`, specialized F/G reconstruction | Direct getters and one local spectral reconstruction per RHS | Register QG with ordinary operations and generalize component masks. Preserve optimized Boussinesq F/G paths. |
| Evolution | `WVForcing` registry, nonlinear flux, `WVCoefficients`, `WVModel` integrator mixins | Same lifecycle, QG spatial/spectral stages and optional diffusion exponential coordinates | Retain lifecycle and family-keyed tendencies. The equation-specific spatial projection remains a transform responsibility. |
| Persistence | `CAAnnotatedClass`, stored scientific matrices, coefficient annotations | Same annotated stream and stored canonical scientific operators | Reuse existing factories and stream; never solve new scientific modes on restart. #352 owns broader transfer qualification. |

`WVPrimaryFlowComponent` and `WVTotalFlowComponent` additionally enumerate analytical modes, pair conjugates, initialize random amplitudes, and supply orthogonal energy factors. Those capabilities are stronger than selecting coefficients. Preserve them for existing models; a generic QG selector must not pretend to supply an analytical primary-mode enumeration or a diagonal positive generalized-energy metric.

In particular, `WVStratification.verticalProjectionOperatorsForIGWModes` explicitly sets `UpperBoundary.rigidLid` and calls `verticalProjectionOperatorsWithRigidLid`. The Boussinesq geometry allocates both wave and balanced arrays using one `Nj`. These are concrete replacement points for #366, not reasons to discard the Fourier geometry, physical-family mixins, or model lifecycle. The free-surface prototype should be a peer transform; avoid inheriting the entire QG equation implementation merely to reuse balanced matrices. Extract shared free-surface balanced operator construction/reconstruction only when the second executable model establishes the exact reusable part.

## State and component contract

`coefficientStateAnnotations()` supplies the ordered families. Each annotation describes dimensions, units, numeric domain, basis, and persistence treatment of empty families. The actual family array supplies its shape. Neither `Nj` nor `spectralMatrixSize` is a universal coefficient shape. In particular, QG `Amda` is real and independent of the APV count, while legacy Boussinesq stores the mean inside `A0` and pairs wave coefficients to produce real fields.

`coefficientState(flowComponent=...)` returns a family-keyed copy of the canonical reference-time state. It neither mutates the transform nor applies wave phase evolution. A component mask is scalar zero/one or exactly the corresponding family shape; omitted families select zero. Masks select modes and do not resample, project, or redefine their normalization. Arbitrary masks must respect the concrete model's conjugacy constraints; existing primary components already encode those constraints.

`WVFlowComponent` gains family-keyed masks while retaining `maskAp`, `maskAm`, and `maskA0` compatibility. Union and containment operate over discovered families. Components belong to one transform. Immutable new-family selections keep registered field caches unambiguous; existing legacy mask behavior is retained.

The existing `hasPVComponent`/`hasWaveComponent` flags on a component describe its legacy `A0`/`Ap`/`Am` masks. New code discovers actual selections through `coefficientMasks`; it does not use those compatibility flags as a universal physical classification. Legacy analytical random initialization rejects unsupported canonical families explicitly.

## Reconstruction and projection

`reconstructFields(variableNames,flowComponent=...)` returns named physical arrays at the current time without mutating coefficients. The base implementation reuses the existing Boussinesq operation factory and optimized component transforms. QG reconstructs the selected canonical state once, then derives the requested fields. Ordinary operation lookup and direct field access use the same model mathematics and annotation-driven cache lifecycle.

The initial QG field set is `psi`, `u`, `v`, `eta`, `qgpv`, `ssh`, `ssu`, `ssv`, and `uvMax`. Mean displacement and full mean QGPV are included. Mean SSH uses the existing zero gauge. A full pressure field and prognostic vertical velocity require their own scientific reconstruction contract; they are not synthesized from a zero-mean QG streamfunction.

Projection is deliberately specified by physical input semantics rather than a universal matrix shape. Existing Boussinesq velocity/displacement projection and QG APV-first/residual-endpoint projection remain model methods. QG nonlinear products are evaluated on the shared physical grid, then `projectQuasigeostrophicSpatialTendency` returns the resolved family-keyed tendency. General sampled-field vertical differentiation uses #360's calculus; it does not project arbitrary fields onto APV modes before differentiating. #366 must demonstrate which additional shared projection hook is actually needed before introducing it.

## Energy, caches, and lifecycles

Selected fields add linearly when masks form a partition. Physical quadratic inventories generally do not: the QG APV and zero-APV families have cross terms. Evaluate the selected state with `quadraticDiagnostics`; recover a partition's total inventory using its self terms plus pairwise polarization terms. Do not sum diagonal family energies or use signed generalized energy as an error norm. Existing orthogonal Boussinesq energy factors remain valid for that basis.

Coefficient setters invalidate state-dependent operation results using the existing annotation maps. Time changes invalidate linearly evolving results. Immutable basis, projection, and metric operators are separate from cached physical fields and survive coefficient mutations. A QG RHS continues to use one local reconstruction shared by its forcing stages, avoiding a persistent collection of stage-specific physical states. No forcing priorities, observers, integrator state packing, or restart schema change is required for component selection.

## Verification and remaining gate

Exercise pure and mixed APV/zero-APV/MDA states, both active endpoints and empty endpoint families, independently sized APV/MDA arrays, ordinary operation lookup, component sums, physical-energy cross terms, and coefficient cache invalidation. Run existing QG forcing, ordinary/exponential integration, output, and restart controls. Exercise the same selection/reconstruction surface with existing variable-stratification Boussinesq wave, geostrophic, inertial, and MDA components, including time-dependent phases and analytical primary-component behavior.

These Boussinesq controls validate compatibility with the existing hierarchy. They do **not** satisfy #366: that issue requires the manuscript's linear free-surface equations, pressure and vertical-velocity coupling, constant/variable stratification, free-surface residuals, source-driven evolution, and stored-state continuation. Use `literature/ape-apv-free-surface/main.tex` and its linear-solutions/projection notes as the scientific authority. Keep #355 open until that executable demonstration has exercised these contracts; #352 then broadens cross-model persistence and resolution transfer.

The manuscript inspected at `0a2edf4199aed1a195778c2ae66dea41118c9265`, equations `linear-solutions-wave-summary` and `linear-solutions-wave-normalization`, supplies the fixed-wavenumber wave boundary condition and its surface normalization term. The installed InternalModes authoring provider already documents `IMInternalModes.waveModesAtWavenumber` with `IMBoundaryCondition(a=0,b=1,c=1,d=0)` for the free surface. The next scientific step in #366 is to verify that provider's free-surface modes, including the external surface-gravity mode, against those equations before adapting polarization, projection, and independent family counts. A boundary-condition option alone does not demonstrate the full model's pressure, displacement, and vertical-velocity consistency.

## Implemented evidence

On MATLAB R2025b Update 4, 118 affected tests passed: the new shared-contract tests plus existing total-component enumeration, operation registration/caching, component surface diagnostics, QG transform/persistence, invariant diagnostics/conservation, density forcing, and ordinary/exponential integration. Five shared-contract tests passed again after analyzer-only local-variable/scalar-check corrections. Production Code Analyzer has no blocking findings; the two new test files have no `checkcode` findings. API documentation generation and consistency checks passed (2357 files, 4817 routes, zero validation failures or drift).

The new controls use a 100 km square, 1000 m deep domain at latitude 30 degrees. QG uses an 8 × 8 × 33 grid with constant `N2=1e-4 s^-2`, `g0=.02 m s^-2`, `gd=.03 m s^-2`, and one/both inactive endpoint controls. It verifies independent APV/MDA counts, real MDA, component field sums to absolute tolerance `2e-12`, physical energy against quadrature to relative tolerance `1e-7`, and energy polarization to relative tolerance `1e-13`. The existing Boussinesq control uses an 8 × 8 × 17 grid and `N2=1e-4*exp(z/1000) s^-2`, all four physical components, and a 1234 s phase advance; component field sums agree to `1e-12` absolute tolerance. These are architectural regression tolerances, not a resolution-accuracy claim or a substitute for #351's error estimates.

## Peer-transform evidence from the mixed-state increment

`WVTransformFreeSurfaceBoussinesq` now uses the shared coefficient, operation, component, and cache contracts with independent wave, APV, active-endpoint, inertial, and MDA counts. It reconstructs pressure and vertical velocity, projects admissible pure/mixed states, accounts for positive physical energy with balanced cross terms, and evolves exact reference-time phases. The common free-surface balanced scientific construction and assessment helpers are extracted to `+WVInternal`; QG's public behavior and automatic selection remain intact. Legacy physical-family mixins remain intact for their existing layouts; their rigid-lid/common-Nj initializers are not installed in the new peer.

No new generic projection hook was necessary: the new model owns `projectFields`, with APV-first and residual-endpoint balanced recovery followed by the manuscript's observable wave projector. `t0` changes now invalidate time-dependent fields through the existing base cache mechanism. The new transform's stationary component fields preserve their caches when time changes. Stored scientific operators are unchanged by state/time mutations and support direct in-memory construction without a mode solve.

The quantitative study, retained-design decisions, public factory/field/projection contract, and limitations are in `Documentation/Validation/Issue366MixedBoussinesqTransform.md`. Seven new tests and 129 affected regression tests passed. This established the mixed-state transform prerequisite. The subsequent forced-evolution increment below exercises source/tendency and annotated continuation contracts.

## Forced-evolution and restart evidence

The new peer now implements model-specific `projectSources` and `coefficientTendency`, reusing the shared balanced source operators and the existing `NonhydrostaticSpatial` forcing stage. Wave sources use the defining continuous generalized-energy dual, avoiding a residual subtraction that would require an untruncated balanced source expansion. `WVPrescribedBoussinesqSource` persists its physical patterns and absolute-time cosine clock. No universal projector, forcing category, or hierarchy rewrite was required.

`WVModel(wvt)` and `WVCoefficients` already advance all six independent reference-time families through ordinary fixed RK4. The existing analytical `shouldUseLinearDynamics=true` option continues to hold those amplitudes fixed; no legacy meaning changed. Source and operator annotations use the existing flat stream and factory lifecycle for stored continuation without a new eigensolve. Explicit fixed steps are qualified; adaptive family tolerances and automatic timestep selection remain outside this increment.

`Documentation/Validation/Issue366ForcedBoussinesqEvolution.md` records independent source pairings, the full forced equations and work identity for a resolved mixed source, fourth-order temporal convergence, and uninterrupted/restarted agreement for constant and variable stratification. Together with the preceding wave and mixed-state studies, this supplies the bounded executable #366 evidence required to finalize #355 after review. #352 retains broader persistence/resolution transfer; #354 retains released-provider, install, and CI qualification.
