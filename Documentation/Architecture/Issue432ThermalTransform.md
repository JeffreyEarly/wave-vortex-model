# T1: Complete thermal transform connections to WVM

Status: implementation design for [T1 #432](https://github.com/JeffreyEarly/wave-vortex-model/issues/432). The public API below is proposed for T2–T10; it is not implemented by this document or its manufactured interface fixture. The existing complete thermal prototype already works for the declared linear seasonal problem. T1 specifies its production integration, not a replacement scientific formulation.

T2 construction and reconstruction are now implemented; see the [T2 evidence and API clarifications](../Validation/Issue433/README.md). Integration and subsequent capabilities below remain downstream requirements.

## Baseline and evidence

The audited WVM v5 baseline is `92ad155da45adafc319e6cf3a3233d200e889493` on `feature/v5.0-free-surface-qg`. InternalModes is the released `v2.0.0-beta.4`, whose annotated tag resolves to `f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`. Use the existing `tools/configureCIEnvironment.m` with OceanKit snapshots, not the older sibling `internal-modes` or `internal-modes-evp` checkouts. The WVM manifest still reports 4.3.0; the commit identifies this unreleased v5 development baseline.

The scientific starting point is `Documentation/Experiments/Diffusion/TestCompleteThermalModes.m`, particularly `completeThermalPage`, `thermalSineResponse`, and the independent physical-depth `reference`/`response` helpers. Preserve the independent reference when promoting runtime assembly. [The original report](../Validation/Issue353CompleteThermalModes.md) records 30/30 observable/time checks at 257 and 385 complete WKB directions, and 26/30 at 129. These are combined linear response results, not individual continuum eigenfunction qualification or a nonlinear resolution prescription. Its older research-only wording is superseded for the optional peer by [roadmap #389](https://github.com/JeffreyEarly/wave-vortex-model/issues/389); the primary adiabatic transform and v5 release remain independent.

## Object, state, and construction decisions — T2

Introduce `WVTransformFreeSurfaceThermalQG < WVGeometryDoublyPeriodicStratified & WVTransform`. Do not subclass `WVTransformFreeSurfaceQG`: its APV inversion and coefficient semantics do not describe thermal amplitudes. Reuse its geometry lineage, physical formulas, and family interfaces, extracting shared helpers only when the peer requires them. No second model, observer, or integration hierarchy is introduced.

The scientific factory will be `fromStratification(domainSize,gridSize,N2Function=...,thermalModeCount=...,mdaModeCount=...,kappa_z=...,latitude=...,g=...,constructionOptions=...)`. The ordinary constructor will take validated `scientificState=...`, optional `coefficientState=...`, and `t=...`; it performs no eigenproblem or hidden file I/O. Construction options name polynomial count, physical sampling and assembly quadrature independently, plus `gramTolerance`, `modeConvergenceTolerance`, `boundaryResolutionTolerance`, `quadraticAliasingTolerance`, and `shouldCheckQuadraticAliasing`. Horizontal `shouldAntialias` remains an independent factory option. Reuse current qualified defaults for shared controls; report their resolved values, and do not reinterpret them as seasonal response tolerances. Do not equate `Nz`, inherited `Nj`, retained thermal count, and MDA count; `Nj` is a compatibility value equal to the thermal count and never a generic coefficient shape.

Initial support is fixed, positive constant or exponential stratification, an f-plane with nonzero f, scalar nonnegative constant diffusivity, and both active endpoints. Reject other profiles, variable diffusivity, inactive endpoints, beta, and wave operations explicitly. Constant stratification uses a linear WKB coordinate; the exponential case uses the existing mapping. Automatic thermal count selection is outside the first implementation: callers supply the complete count, and failed qualification rejects that configuration rather than truncating the basis.

| Canonical object | Shape and meaning | Units and rules |
| --- | --- | --- |
| `Ath` | `thermalModeCount × numel(klNonzero)`; complete thermal amplitudes | complex double, m/s under the normalization below; all directions retained |
| `Amda` | independent `mdaModeCount × 1` horizontal mean | real double, m; reuse existing MDA displacement convention |
| `thermalDirection` | `1:thermalModeCount` | ordinal only, never an APV index or cross-resolution identity |
| `thermalRatesPerDiffusivity` | `thermalModeCount × numel(khUnique)` | m^-2; dimensional rates are `kappa_z` times these values |
| Scientific maps | one set per unique nonzero horizontal radius | reconstruct pressure/streamfunction, derivatives, buoyancy, QGPV, SSH, and both endpoint anomalies |

Build the complete pressure polynomial space before any APV truncation. Apply the prototype's positive physical-energy QR, then diagonalize the unit-diffusivity generator. Retain every direction, including stationary directions. For public units, normalize each reconstructed eigenvector so that its depth-averaged positive physical norm for unit amplitude is one; then the streamfunction columns have units m and `Ath` has units m/s. Apply the same diagonal rescaling to every field map, left inverse, and source map. Normalize phase using the first largest-magnitude polynomial coefficient made real positive, with conjugate eigenvectors normalized as pairs. This is a coordinate normalization only; T2 must reproduce the original physical response after conversion. Shared APV Gram/product assessment kernels may be reused only after adapting their metric and projection to the thermal space. Constructor evidence does not certify every highest-index eigenvector as a continuum mode: thermal refinement must assess complete operator/physical response at fixed trial space and increased bandwidth separately, preserving all directions. Modes remain nonorthogonal: never identify physical energy with `sum(abs(Ath).^2)`.

Store a conjugate-direction permutation for any complex eigenpairs. Real physical fields require amplitudes at opposite Fourier wavevectors to be the conjugate amplitudes with that permutation, rather than assuming each thermal eigenvector is real. Use existing compact horizontal support and Hermitian weighting; enforce self-conjugate constraints wherever that layout retains such columns. Store radius/column maps and actual counts. Eigenvalue sorting supplies display order only. Do not clip positive eigenvalues, discard fast modes, or remove a null direction. A numerically defective or inaccurate eigendecomposition rejects construction with spectrum, conditioning, residuals and failed physical-control evidence; no automatic Schur fallback is promised in this first implementation. T2 establishes numerical acceptance from the existing physical error allowances and independent controls, not an arbitrary condition-number cutoff.

### Means and zero diffusion

Keep the existing independently resolved MDA family for the zero horizontal wavenumber, including its column-integrated buoyancy direction. Use stored MDA reconstruction and the conservative `WVInternal.densityDiffusionMDA` operator. Do not construct the nonzero-radius pressure basis at zero radius: its constant-pressure gauge makes the positive energy metric singular. Preserve the current zero mean SSH gauge, zero mean horizontal velocity, and MDA contributions to displacement, buoyancy, QGPV and endpoints. Mean diffusivity equals `kappa_z`; no second switch silently freezes it. Periodic interior/endpoint Jacobians contribute zero horizontal means by their conservative formulation. Initial campaign MDA is zero, but arbitrary supported finite MDA must survive storage and homogeneous evolution. Reject nonzero-mean external QGPV/endpoint source patterns until a separate physically compatible mean-source projector is qualified; never discard them silently.

Compute the thermal basis from the unit-diffusivity operator even when `kappa_z=0`; zero diffusivity sets all actual diffusion rates to zero without rediagonalizing a zero matrix. Keep exact physical null directions and measured roundoff residuals distinct. Add `withDiffusivity(kappa_z)` returning a new transform with identical basis, coefficients, time and physical state, but new rates and fresh computational caches. Scientific arrays and diffusivity are read-only on an existing object. A changed object requires a new model/integrator attachment; changed physics starts a new campaign directory.

## Physical fields and projection — T2, T4, T5

For each nonzero Fourier radius, retain the prototype's definitions, with z in [-D,0]:

$$\eta = -f\psi_z/N^2,\qquad \mathrm{ssh} = f\psi(0)/g,\qquad \eta_i = \eta - (1+z/D)\mathrm{ssh},\qquad b = -N^2\eta_i,\qquad q = -k_h^2\psi - f\eta_z.$$

Velocity is u = -psi_y and v = psi_x. Endpoint anomalies are eta_i(0) and eta_i(-D), in surface-bottom order. Preserve separate endpoint accuracy tests. Buoyancy uses m/s^2, QGPV s^-1, displacement/SSH m, streamfunction m^2/s, and velocity m/s. Physical buoyancy b must not be confused with the existing QG spatial hook's endpoint-displacement variable `b`.

Provide `reconstructFields(variableNames,flowComponent=...)`, ordinary registered operations, and `quasigeostrophicSpatialState()` with the same physical array semantics as the current QG method: interior `Nx × Ny × Nz`, endpoint `Nx × Ny × 2`. Support `psi`, `u`, `v`, `eta`, `eta_i`, `buoyancy`, `qgpv`, `ssh`, `ssu`, `ssv`, `uvMax` and `endpointAnomalies` (Nx by Ny by 2); pressure, vertical velocity, particles, and analytical APV/wave mode enumeration are not implicitly supported. Coefficient selection uses family masks; selecting thermal directions does not produce APV diagnostics.

Provide `projectState(qgpv,endpointAnomalies,meanDisplacement=...)` for initialization/resolution transfer, returning family coefficients and physical residuals. For nonzero radii, solve the constrained physical-depth weighted least-squares QGPV fit subject to exact represented endpoint anomalies, using stored reconstruction maps and independently qualified quadrature. Project mean displacement with the existing MDA projector. Report omitted QGPV and reconstructed-field content; reject incompatible endpoint constraints instead of silently relaxing them. In contrast, `projectQuasigeostrophicSpatialTendency(Fq,Fb)` applies the weak source dual and returns family-keyed rates. Do not call the state fitting routine merely because its input dimensions agree.

In the prototype's positive-energy QR coordinates, the strict surface displacement source is `-f*Q'*surface'`, the bottom source is `f*Q'*bottom'`, and the interior source pairing is minus the streamfunction test basis paired with Fq over physical depth. Transform these columns into thermal coordinates with the true left inverse of the eigenvector map, including normalization. The strict seasonal source acts only on the top displacement equation in m/s, with zero direct interior QGPV and bottom tendency. It is not an inward buoyancy-flux source. Insulating homogeneous diffusion remains the same weak operator at both active boundaries.

The new factory retains all polynomial directions and stores endpoint derivatives and weak pairing data. FFT-backed cosine transforms apply to polynomial values/coefficients and derivatives with WKB Jacobians; physical quadrature and the dense eigenvector maps remain separate. T4 defines and qualifies nonlinear padding/overintegration independently of linear construction. Constant-stratification controls and independent manufactured source pairings must verify these formulas before production use.

## Integration, ownership, and cache audit — T3–T7

| Existing hook | Decision and downstream work |
| --- | --- |
| `coefficientStateAnnotations`, `coefficientState`, `WVCoefficients` | Override annotation discovery for Ath/Amda; reuse family-shaped copying, packing and ordinary fixed integration. No fake Ag_q/Ag_0 fields. |
| `coefficientAbsoluteTolerances` | Override: the base method still computes legacy spectral-energy tolerances before its new-family fallback. T3 uses physical error norms; do not claim a scalar coefficient tolerance is that norm. |
| `WVOperation`, `variableWithName`, cache maps | Register peer reconstruction; setters call existing coefficient-cache invalidation despite its legacy ApAmA0 name. Scientific maps remain untouched. |
| `reconstructFields` | Implement the peer override as QG does; the base operation factory still assumes legacy total-flow operations. Reuse one reconstruction per RHS and requested-field work where available. |
| `coefficientTendency(excludingForcing=...)` | Peer owns physical reconstruction/source projection and family accumulation; reuse current QG forcing ordering and exclusions. |
| `WVDensityDiffusionIntegrator` | Its constructor requires WVTransformFreeSurfaceQG and a WVVerticalDiffusivity registration; modalState/fromModes, norms, seasonal projection and damping caps assume APV families. Adapt these boundaries in T3, retaining the existing controller. |
| `WVModel` | Reuse lifecycle, WVCoefficients, accepted-state restoration, and output scheduling. Geometry must supply diagnostics/CFL quantities such as inertialPeriod and uvMax. `shouldUseLinearDynamics=true` is analytical phase evolution, not forced thermal integration. |

The thermal transform is the single owner of diffusivity and the homogeneous generator. Reject registration of `WVVerticalDiffusivity` on it, preventing double diffusion. `linearEvolutionData()` supplies a transient struct with `familyNames`, `familyShapes`, `rates`, `toModes`, `fromModes`, `physicalNormFactors`, and `projectSource`. Rates use the same column-major packing as `toModes`; Ath maps are identity and Amda uses the stored mean eigenmaps. Function handles belong only to this computational adapter, never canonical persistence. Physical norm factors preserve separate QGPV, buoyancy, speed and endpoint RMS reconstruction with the actual Fourier weights. The existing exponential integrator consumes this adapter. Implement narrow adapters for the existing APV owner and new thermal owner; do not fork step control, harmonic response, ETDRK4, rejected-stage restoration, or observation scheduling.

`WVSeasonalSurfaceAnomalyForcing` remains the sole owner of amplitude, period, phase, pattern and absolute source clock. T3 evolves it analytically and excludes its callback from explicit stages; diagnostic callbacks return that same physical source. `coefficientTendency` includes homogeneous diffusion and source by default for an ordinary RHS, while explicit exponential stages exclude both analytically handled processes. Unsupported ordinary-RHS paths must reject rather than omit diffusion. Coefficients always denote the instantaneous physical state, never an integrator departure buffer.

Immutable basis/projection/metric data survive coefficient and time changes. Coefficient mutations invalidate physical fields and state-dependent budgets; time invalidates time-dependent source evaluations. New diffusivity invalidates rates, exponential factors and integrator attachment. Forcing configuration changes require source-cache rebuild/reattachment. Runtime closure rates depend on the current physical state. T6 must supply physical action and stability caps for its chosen closure; never apply the existing `dampAg_q` taper to Ath indices. APV diagnosis remains offline except when an explicitly APV-defined closure requires a stage-wise map.

## Canonical persistence and analysis — T8–T10

`scientificState` is a versioned validated value containing geometry/rotation/profile samples and mapping identity, physical and assembly quadrature, counts and horizontal-radius layout, polynomial-to-mode and inverse maps, field/derivative/endpoint maps, source duals, normalization/conjugacy metadata, unit-diffusivity rates/generator, MDA scientific state, diffusivity, and construction tolerances/policy. The struct is the constructor input vocabulary; persist its numeric fields through ordinary flat annotations and named dimensions, not as an opaque MAT blob. Store operators once, coefficients and time per record. Record full `constructionAssessment` separately because it is transient, as in current v5.

`[wvt,ncfile] = waveVortexTransformFromFile(path,iTime=...,shouldReadOnly=...)` and its group adapter restore through the existing annotated dispatch, validate required arrays, and construct cheaply. The concrete reader must return an open file handle when requested, close it when only the transform is requested, and close on failure; the generic WVTransform reader requests both outputs. Restoration may rebuild numeric caches but may not invoke InternalModes or a scientific eigensolve. Restore forcing objects and their absolute clock; attach the integrator explicitly through existing setup semantics. T8 qualifies full WVModel streams, committed-prefix recovery, resolution transfer, and fresh-process restoration without InternalModes. T1's direct annotated snapshot is only preliminary evidence for that path.

Transfer resolution by physical reconstruction and projection with explicit loss estimates, not by copying eigenvector indices. T9 uses `WVTransformFreeSurfaceQG` only as a diagnostic transform, independently refining its quadrature and APV band. Retained components plus unresolved residual must account for the thermal physical state, including both endpoints. T7 inventories use stored physical Gram matrices and cross terms. T10 measures whole-model accuracy and cost including dense maps, output and analysis; no speedup or campaign readiness follows from this design.

### Proposed usage after downstream implementation

```matlab
w = WVTransformFreeSurfaceThermalQG.fromStratification([500e3 500e3 4000],[64 64 513],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300),thermalModeCount=257,mdaModeCount=321,kappa_z=1e-5,latitude=24);
[state,residual] = w.projectState(qgpv,endpointAnomalies,meanDisplacement=meanDisplacement);
w.Ath = state.Ath;
w.Amda = state.Amda;
% Register the strict seasonal source and qualified drag/damping using T5/T6.
model = WVModel(w);
model.setupIntegrator(integratorType="exponential");
model.integrateToTime(finalTime);
file = w.writeToFile('thermal-state.nc');
file.close();
restored = WVTransform.waveVortexTransformFromFile('thermal-state.nc');
% T9 diagnoses restored physical fields with a separately qualified APV transform.
```

Counts here illustrate independent inputs, not recommended nonlinear defaults. The proposed factory validates them; T10 chooses campaign counts. qgpv, endpointAnomalies and meanDisplacement are caller-supplied physical arrays. Full stream/restart and forcing examples belong to T8; the snapshot example does not assert a completed production restart path.

## T1 executable evidence and verification ledger

`TestThermalInterface` and `ThermalInterfaceFixture` live beside the optional diffusion study and are explicitly invoked. The fixture derives directly from WVTransform, defines one complex 3-by-2 family, a 4-by-3 real reconstruction map, and a deterministic time-dependent prescribed tendency. It contains no thermal eigensolve, horizontal Fourier physics, MDA or closure. Generic fixed integration, annotations and caches are real WVM paths; manufactured units and columns are not the proposed physical thermal normalization or Fourier reality test.

The tests check family discovery without APV coefficients, registered field caching and mutation, analytical integration of `(1+t)*source`, exact snapshot recovery of arrays/time/source, and restored versus uninterrupted continuation. Its scientific factory always throws; restoration uses only the supplied arrays. This proves cheap annotated construction and generic class dispatch, not T8's stronger provider-unavailable full-model continuation requirement. The prescribed tendency is a transform callback, not a seasonal-forcing compatibility test.

The first interface run exposed missing fixture geometry metadata (`inertialPeriod`); the first restore attempt exposed the generic reader's two-output/options signature. Both were corrected in the fixture, with no runtime change. These findings are incorporated above. A final coherent run passed all three interface methods and all five `TestSharedResolvedContracts` methods on MATLAB R2026a (13 September 2026). The prescribed tendency and continuation tests use an absolute coefficient allowance of 2e-14; arrays and time restored directly are checked exactly. Field-cache tests verify one evaluation before mutation and a second afterward. The shared suite covers existing QG fields, independent families, energy cross terms, cache behavior, and Boussinesq families/phases.

The initial Code Analyzer pass reported only seven STOUT findings on deliberately throwing unsupported fixture methods. Those signatures are retained for abstract-interface conformance (and the disabled factory), with targeted documented suppressions. No test or production behavior changed in that cleanup. The follow-up fixture analyzer check returned no findings; the test file had no findings in the original pass. `docs:check` passed once: 2,368 files, 4,839 routes, zero validation failures and zero generated differences. Subsequent edits only completed this non-generated architecture ledger and documented analyzer suppressions.

Reproduction from the WVM authoring root (local `matlab -batch` must run outside the macOS sandbox):

```matlab
restoredefaultpath;
sourceRoot = pwd;
oceanKitRoot = fullfile(fileparts(sourceRoot),'OceanKit');
addpath('tools');
configureCIEnvironment(sourceRoot,oceanKitRoot,documentationPackageSpecifier="ClassDocumentation@1.3.2");
% MATLAB startup/package registration can retain older sibling paths.
paths = string(strsplit(path,pathsep));
workspacePrefix = string(fileparts(sourceRoot))+filesep;
stale = startsWith(paths,workspacePrefix) & ~startsWith(paths,string(oceanKitRoot)+filesep) & ~startsWith(paths,string(sourceRoot));
if any(stale), rmpath(char(join(paths(stale),pathsep))); end
for symbol = ["IMSolverSpectral","IMInternalModes"]
    locations = string(which(symbol,'-all'));
    assert(numel(locations)==1 && startsWith(locations,fullfile(oceanKitRoot,'InternalModes-2.0.0-beta.4')));
end
addpath('Documentation/Experiments/Diffusion','UnitTests');
results = runtests({'Documentation/Experiments/Diffusion/TestThermalInterface.m','UnitTests/TestSharedResolvedContracts.m'});
assertSuccess(results);
checkcode('Documentation/Experiments/Diffusion/TestThermalInterface.m','-id');
checkcode('Documentation/Experiments/Diffusion/@ThermalInterfaceFixture/ThermalInterfaceFixture.m','-id');
buildtool docs:check
```

Dependency ledger: InternalModes 2.0.0-beta.4, SplineCore 2.2.0, Distributions 2.0.0, chebfun 5.7.0, NetCDF 1.0.2, ClassAnnotations 1.2.1, and documentation-only ClassDocumentation 1.3.2. Both InternalModes symbols resolved exclusively inside the beta.4 snapshot after removal of stale sibling paths. MATLAB's startup emitted package-path warnings before that cleanup; the fixture also emits WVM's expected no-damping warning because its manufactured tendency intentionally contains no closure.

The full seasonal study, nonlinear/forcing qualification, stream recovery, provider-unavailable production restart, release/install tests and performance measurements were not rerun: they are downstream gates, and this fixture does not claim to satisfy them. No required local asset was missing. Package manifests, generated website files, experiment pins, snapshots and historical thermal reference data remain unchanged.
