# T4: Nonlinear thermal QG advection

Implemented against WVM `aed3c284075b62a5a4412bef13913beefb37c33d` on `feature/v5.0-free-surface-qg`, following the [T4 plan](../../Architecture/Issue435ThermalNonlinearPlan.md). This increment qualifies nonlinear advection and its numerical projection for bounded manufactured states and short runs. It does not qualify drag, a damping closure, full restart, arbitrary nonlinear trajectories, production resolution or whole-model throughput.

## Usage and ownership

```matlab
w = WVTransformFreeSurfaceThermalQG.fromStratification( ...
    [5e5 5e5 1000],[12 12 65],N2Function=@(z)1e-4*ones(size(z)), ...
    thermalModeCount=17,mdaModeCount=4,kappa_z=0, ...
    shouldCheckQuadraticAliasing=true);
% Set a nonzero physical initial state through the existing projection interface.
w.addForcing(WVNonlinearAdvection(w));
model = WVModel(w);
model.setupIntegrator(integratorType="exponential");
```

Nonlinear advection is explicitly registered, not installed by the constructor. Registration requires horizontal antialiasing and accepted product-quadrature evidence. Linear-only construction remains available. `thermalLinearDynamics=true` continues to select T3's explicit linear configuration and rejects a contradictory nonlinear registration. Changing registration after attachment requires matching integrator setup. Diffusion and the exact seasonal source retain T3's single-owner/exclusion rules. Other physical nonlinear forcings and unsupported closures still reject.

The thermal forcing uses the existing QGSpectral callback because its physical products must be integrated before native resampling. Its coefficient tendency still derives from complete physical QGPV and both endpoint Jacobians, not a coefficient-index closure. The adiabatic QG callback and its behavior remain unchanged. Portable nonlinear thermal execution is explicitly unavailable.

## Product quadrature and projection

The product worker reconstructs streamfunction and QGPV directly on physical-depth Gauss quadrature, and both endpoint fields directly at the boundaries. Fourier derivatives and transforms use WVM's existing compact, dealiased geometry. It forms interior and endpoint advection, measures the roundoff horizontal means against the uncancelled product scale, removes only those nonlinear means, and projects with the thermal weak dual. External source means remain subject to the existing rejection policy. Uniform MDA has neither horizontal gradients nor horizontal velocity and contributes no Jacobian; its signed canonical state is preserved.

`WVInternal.projectThermalWeak` now applies the common left dual to polynomial moments and endpoint sources. The native external-source method still interpolates native samples to its source quadrature. The nonlinear worker instead integrates its product-grid values directly, without downsampling. Equal-radius matrix products are grouped, and immutable product maps are cached separately from coefficients and time. A pure nonlinear/seasonal RHS shares the product reconstruction; arbitrary additional callbacks that request native physical fields retain a separate native reconstruction.

For the supported constant/exponential profile, the WKB Jacobian J is affine in the mapped coordinate s. QGPV is a combination of P, its second s derivative, and its first s derivative divided by J. Thus the weak interior products require polynomial moments under the dz and dz/J measures. The constructor compares normalized moment Grams spanning triple-product degree, using product count q, reference count 2q+1 and a second reference 4q+3. The default q is max(257,3*n+1). The default residual allowance is 1e-8, with one fifth allocated to reference refinement. It does not invoke a plain 3/2 rule as a mapped-operator certificate.

For the measured 17/25/33 spaces, counts are 257/515/1031. Complete assessments are stored in the JSON files. For example, the 33-direction exponential case has maximum primary residual 8.10e-14 and reference residual 9.21e-14. This is quadrature evidence; independently assembled interactions and evolving physical fields provide the additional checks below. Constructor acceptance does not certify arbitrary coherent states or continuum bandwidth.

## Persistence

Schema 2 stores the nonlinear policy flag, quadrature count, allowance and primary/reference residuals. All are immutable scientific configuration; product maps remain transient. Restoration validates the stored certificate without a scientific eigensolve or a fresh product assessment. Schema-1 canonical arrays and files migrate explicitly to schema-2 linear-only defaults. Tests cover both an actual schema-1-format file and schema-2 recovery with identical nonlinear tendencies. Registered forcing/full-model continuation remains T8's qualification responsibility.

## Independent interaction controls

The manufactured pressure fields are monomials in the mapped coordinate with independently differentiated analytical QGPV and endpoint formulas. Complex amplitudes include signed conjugates. Direct signed Fourier convolution and separate 1025/2049-point physical quadratures supply the reference; neither the runtime FFT product kernel nor its cached pairing map evaluates that reference. The test reuses the authoritative thermal dual and the previously qualified polynomial basis.

Tests include nonparallel low and high vertical powers, mixed interior/boundary structures, retained Fourier-cutoff interactions, real-field/conjugate constraints and signed means. The cutoff uses the actual retained geometry, including its nonrectangular support; modes outside it cannot alias into retained interactions. A single-wave zero-Jacobian case is only a null control. The APV assessment wrappers are not called on thermal states: their manufactured/reference strategy is adapted, while their APV inventories and duals remain unchanged.

Declared physical error floors for QGPV, buoyancy, speed, surface and bottom tendencies are respectively 1e-22, 1e-19, 1e-19, 1e-15 and 1e-15 in their tendency units, plus 1e-8 times reference RMS. Independent reference differences receive one fifth of that allowance. Across the six recorded constant/exponential and 17/25/33-direction cases, the largest error/allowance is 9.96e-6 and reference-change/allowance is 1.85e-6. All are below their respective 1 and 0.2 limits.

Changing native sampling from 65 to 129 at fixed scientific bandwidth changes the nonlinear coefficient tendency by exactly zero in these controls. Native near-surface buoyancy-gradient tendencies agree to at most 2.48e-13 relative. Nonlinear quadrature, native sampling and bandwidth are therefore measured separately.

## Nonlinear evolution and invariants

Short unforced, nondiffusive runs use a 500 km square domain, 1000 m depth, latitude 24 degrees, constant N2=1e-4 or N2=1e-4 exp(2z/1300), three nonparallel pressure components, signed nonzero MDA and duration 1e5 seconds. This is a manufactured control, not the 4 km seasonal campaign. No adiabatic/APV coordinate conversion enters the RHS.

The positive physical energy has the Galerkin Hamiltonian cancellation in converged quadrature: pairing streamfunction with its own Jacobian vanishes in the dealiased horizontal integral, including each endpoint. QGPV and endpoint variances are reported as truncation-sensitive diagnostics, not assumed to be exact finite-space invariants.

| Profile, 17 directions | Step | Relative energy drift | Relative coefficient change |
| --- | ---: | ---: | ---: |
| Constant | 10000 s | 2.4803e-8 | 0.34666 |
| Constant | 5000 s | 1.1895e-9 | 0.34666 |
| Exponential | 10000 s | 3.2413e-8 | 0.30921 |
| Exponential | 5000 s | 1.5614e-9 | 0.30921 |

The predeclared fine-step energy allowance was 1e-6. Halving the step reduces energy drift about twentyfold. Coefficient change proves nonzero evolution within each fixed basis; it is not a cross-bandwidth error metric. Mean coefficient changes are below 1.2e-16.

Physical trajectory comparisons use a common sampling grid. Relative QGPV differences against 33 directions fall from 6.04e-7 to 7.53e-11 (constant) and 3.25e-7 to 4.73e-11 (exponential) when increasing from 17 to 25 directions. Near-surface gradient differences fall from 1.81e-6 to 2.77e-10 and from 1.07e-6 to 1.76e-10, respectively. Both endpoint comparisons are recorded separately. Variance drifts plateau at the time-error scale for 25/33 directions. These results demonstrate bounded refinement; they do not prescribe a nonlinear campaign resolution.

The nonlinear lifecycle test also exercises actual rejected steps, recovery after a stage exception, and identical accepted trajectories under different passive sampling cadences. A short nonlinear-plus-diffusion/seasonal run verifies the ordinary and exponentially split generators agree. The full T3 257/385 seasonal controls were rerun and still pass all 30 checks; the 129-direction failure remains.

## Cost and limitations

`rhs-cost.csv` reports warmed component medians over five calls on the 12-by-12 grid and 257 product points. These local measurements range from roughly 1.0–3.2 ms reconstruction, 0.3–0.6 ms products and 0.2–1.0 ms projection. Nine radius groups are reused. The reported scratch estimate is approximately 2.9 MB; it is an array-size estimate, not instrumented peak RSS or total model memory. The environment is MATLAB R2026a Update 4, native Apple Silicon, double precision, with an observed default maximum of 18 computational threads. These are representative local costs, not a performance comparison or throughput claim.

Coverage is deliberately bounded: no exhaustive thermal interaction inventory, nonlinear horizontal-grid convergence campaign, 257/385-direction nonlinear run, closure qualification, full restart or long production trajectory was performed. Such missing coverage is not reclassified as a pass. T5/T6/T8/T10 retain those responsibilities.

## Reproduction and verification

Use the existing clean `configureCIEnvironment` with OceanKit snapshots. InternalModes is exclusively `2.0.0-beta.4` (`f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`); unique `IMSolverSpectral` and `IMInternalModes` resolution was checked. Other dependencies remain ClassAnnotations 1.2.1, NetCDF 1.0.2, SplineCore 2.2.0, Distributions 2.0.0 and chebfun 5.7.0; documentation uses ClassDocumentation 1.3.2. The WVM manifest remains 4.3.0, with the commit identifying unreleased v5 work.

```matlab
addpath('UnitTests','tools');
results = runtests({'UnitTests/TestThermalNonlinear.m', ...
    'UnitTests/TestThermalIntegration.m', ...
    'UnitTests/TestFreeSurfaceThermalQG.m', ...
    'UnitTests/TestSharedResolvedContracts.m', ...
    'UnitTests/TestDensityDiffusionIntegrator.m', ...
    'UnitTests/TestFreeSurfaceQGDensityForcing.m'});
assertSuccess(results);
evidence = qualifyThermalNonlinear(outputDirectory);
linear = qualifyThermalIntegration(linearOutputDirectory);
buildtool docs:check
```

| Gate | Result |
| --- | --- |
| Focused tests | 47/47 covered and passing after targeted reruns of the two corrected test setups: 6 nonlinear, 6 thermal integration, 8 thermal construction, 5 shared contracts, 15 APV integration and 7 APV density-forcing tests |
| Nonlinear science | Manufactured interactions and independent reference budgets passed; nonzero evolution, temporal invariant refinement and separate native/bandwidth comparisons recorded |
| T3 seasonal science | 257/385 each pass 30/30; 129 retains 26/30; independent reference and assembly controls passed |
| Code Analyzer | No new findings; three pre-existing WVModel AGROW findings and two pre-existing unused inputs in WVNonlinearAdvection remain |
| Documentation | One coherent build/check cycle passed: 2621 files, 5347 routes, zero failures and zero generated differences |
| Runtime-only layout | Nonlinear WVModel evolution and canonical nonlinear snapshot recovery passed without authoring helpers on the active path |
| Persistence | Actual schema-1 file migration and schema-2 nonlinear restoration passed; full stream restart remains deferred |
| Whitespace/scope | Added/changed lines and new files passed; manifest, snapshots, historical reference harness and experiment pins unchanged |

No required gate remains blocked and no scientific assets were missing. Startup/package-path and existing no-damping warnings were nonfatal. The unrelated untracked `tools/free-surface-initialization-study/` directory remains untouched. The runtime-only check is not an MPM release/install qualification.

## T5 handoff

Extend physical forcing parity through the complete thermal source/tendency map, beginning with quadratic bottom stress. Preserve the seasonal source and homogeneous diffusion ownership already qualified. Keep nonlinear advection and closure selection separate: adding bottom drag is not permission to apply an APV-index damping taper to thermal directions. T6 defines that closure, T8 qualifies persisted continuation, and T10 decides campaign readiness.
