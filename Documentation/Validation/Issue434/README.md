# T3: Thermal evolution through WVModel

Implemented against WVM `2b774cb03d34f87ee0201886e535ffad6f14cfdd` on `feature/v5.0-free-surface-qg`, following [T2](../Issue433/README.md) and the [T3 plan](../../Architecture/Issue434ThermalIntegrationPlan.md). This increment qualifies forced linear thermal evolution and explicit ETDRK4 machinery. Nonlinear QG products, bottom drag/closure, full stream restart and campaign readiness remain downstream.

## Supported configuration

```matlab
w = WVTransformFreeSurfaceThermalQG.fromStratification( ...
    [1e5 1e5 1000],[4 4 65],N2Function=@(z)1e-4*ones(size(z)), ...
    thermalModeCount=17,mdaModeCount=4,kappa_z=1e-5);
pattern = repmat(sin(2*pi*w.y'/w.Ly),w.Nx,1);
w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=1e-7));
model = WVModel(w);
model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true);
model.integrateToTime(86400,shouldShowIntegrationDiagnostics=false);
```

`thermalLinearDynamics=true` explicitly selects forced linear thermal dynamics. It does not change `WVModel`'s separate `shouldUseLinearDynamics` analytical-phase option. Omitting the thermal selection rejects exponential setup. Direct `coefficientTendency(linearDynamics=true)` includes the complete homogeneous generator and registered sources; ordinary adaptive integration remains unsupported because coefficient tolerances are not physical thermal norms.

The thermal transform owns diffusivity. `WVVerticalDiffusivity` rejects thermal construction; use `withDiffusivity` and attach a new model/integrator. The immutable unit-diffusivity thermal and mean generators are multiplied once, including at zero diffusivity. `WVSeasonalSurfaceAnomalyForcing` owns amplitude, period, phase, pattern and absolute clock. Explicit exponential stages omit homogeneous evolution and the analytically integrated seasonal source; registered coefficient-source callbacks use the established QGSpectral interface. Physical nonlinear forcings and APV damping remain unavailable.

## Evolution adapter and shared machinery

`linearEvolutionData()` supplies family names/shapes, packing functions, rates, physical norm factors and the weak source projector. Ath packing is identity. Mean eigencoordinates are derived from the authoritative stored conservative generator, without InternalModes or a scientific reconstruction. Mean inversion validates reality; null directions and all computed rates are retained. The ordinary mean generator and its eigencoordinate propagation are compared with an independent matrix exponential.

MATLAB's default eigenvector balancing produced a normalized residual above the 1e-10 guard for the constant-stratification mean generator. `eig(A,'nobalance')` satisfies that guard without altering the stored matrix. The inverse guard is 1e-8. No rate clipping or reconstructed replacement operator is used.

The existing `WVDensityDiffusionIntegrator` now accepts the thermal adapter at its state/rate/norm boundaries. The APV adapter remains in its existing methods, preserving its batched changes of basis, diffusion-forcing ownership and four-norm behavior. The controller, harmonic integral, ETDRK4 stage functions, accepted-state recovery and output sampling are shared. Exponential factors are evaluated on unique rates and expanded into packed family order. Spatial and mean-coordinate caches are transient and survive coefficient/time changes; a new diffusivity object gets new derived caches. Seasonal sources refresh when forcing objects are replaced or removed.

Thermal error control uses physical QGPV, buoyancy, speed, surface displacement and bottom displacement RMS norms. The last two are separate. Five absolute floors can be supplied; a four-entry vector assigns its endpoint floor to both endpoints. Thermal relative scaling uses the total physical state, including the exact seasonal response, rather than the local departure buffer. Positive quadrature/QR factors include nonorthogonal cross terms and compact Fourier pair weights. APV defaults are unchanged. The scientific response gate independently includes SSH and the full positive physical-energy state norm.

## Scientific response

`tools/qualifyThermalIntegration.m` evolves the actual transform through `WVModel` and compares all six historical observables on days 1, 8, 32, 64 and 91.3125. The unchanged physical-depth research reference uses 385 directions; an independent 513-direction/4097-assembly refinement checks reference adequacy. Runtime assembly is separately refined from 2049 to 4097 at fixed 257 directions.

The reduced 100 km periodic box carries the exact physical wavevector of meridional mode 5 in the 500 km case. Its sine Fourier magnitude is explicitly checked to be 1/2. Depth, exponential stratification, latitude, annual period and source amplitude are unchanged. Physical field amplitudes are compared after dividing out that known Fourier coefficient. This is a linear single-harmonic equivalence, not a reduced-domain nonlinear qualification.

| Complete directions | Native samples | Passed | Worst error / allowance | Worst model–prototype difference / allowance |
| --- | ---: | ---: | ---: | ---: |
| 129 | 513 | 26/30 | 7.84639 | 1.78043e-6 |
| 257 | 513 | 30/30 | 0.0124910 | 8.03292e-5 |
| 385 | 1025 | 30/30 | 0.00102133 | 2.86555e-4 |

The 385-direction constructor rejected 513 native samples with Gram residual 0.0185 against the unchanged 0.01 threshold. Increasing to 1025 samples passed; no construction tolerance was relaxed. Full construction assessments are retained in the accompanying JSON files. The largest assembly-refinement difference is 0.000220197 of an observable allowance; independent reference refinement is 0.000762995. Both are below the 0.2 control allocation.

The 129-direction failure remains visible. Exact linear stepping required 23 accepted steps per resolution across the five requested integration endpoints, with no rejection. This is not evidence of adaptive convergence: a separate manufactured explicit tendency supplies that test.

## Integration controls and verification

The manufactured complex coefficient problem evolves with a known exponential reference. Tightening relative tolerance from 1e-3 to 1e-6 changes accepted steps from 3 to 15 and relative errors from 0.00388145 to 9.8436e-6; both runs reject two trial steps. A deliberate stage exception after an accepted step restores accepted time and coefficients. Changing passive sampling cadence preserves accepted steps and final coefficients exactly while sampled values match the analytic trajectory. The sampling fixture exercises the real controller's output callback path, not full NetCDF restart qualification.

Additional controls cover zero/tiny time, zero diffusivity, null rates, complex Fourier coefficients, changed phase, nonzero absolute start time, signed means, complete ordinary-RHS versus exponential ownership, independent physical norm reconstruction, forcing replacement/removal, cache reuse and required linear selection. Existing APV lifecycle, source, restart and shared-family regressions are retained.

Verification uses MATLAB R2026a Update 4, clean `configureCIEnvironment` setup, and exclusively OceanKit InternalModes 2.0.0-beta.4 (`f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`). Other runtime snapshots are ClassAnnotations 1.2.1, NetCDF 1.0.2, SplineCore 2.2.0, Distributions 2.0.0 and chebfun 5.7.0; documentation uses ClassDocumentation 1.3.2. Authoring manifest remains 4.3.0; the commit records the v5 baseline.

After the clean setup:

```matlab
addpath('UnitTests','tools');
results = runtests({'UnitTests/TestThermalIntegration.m', ...
    'UnitTests/TestDensityDiffusionIntegrator.m', ...
    'UnitTests/TestExponentialTimeFunctions.m', ...
    'UnitTests/TestFreeSurfaceThermalQG.m', ...
    'UnitTests/TestSharedResolvedContracts.m', ...
    'UnitTests/TestFreeSurfaceQGDensityForcing.m'});
assertSuccess(results);
evidence = qualifyThermalIntegration(outputDirectory);
buildtool docs:check
```

| Gate | Result |
| --- | --- |
| Focused tests | 43/43 passed: 6 thermal integration, 15 existing APV integration, 2 time-function, 8 thermal construction, 5 shared-contract and 7 APV density-forcing tests |
| Final closure guard | Affected ownership test rerun passed after adding rejection of unsupported closures |
| Scientific model qualification | Passed 257/385 response and both independent refinement controls; expected 129 failure retained |
| Code Analyzer | No new messages in changed MATLAB files; three existing AGROW messages remain in untouched WVModel code at lines 142, 281 and 283 |
| Documentation | One build/check cycle passed: 2615 files, 5335 routes, zero failures and zero generated differences |
| Runtime-only layout | Forced thermal WVModel integration passed with only root code and manifest runtime folders; unique beta.4 provider resolution verified |
| Whitespace/scope | Passed; no manifest, released snapshot, historical experiment harness or experiment-pin changes |

The runtime-only copy is not an MPM release/install qualification. No required T3 gate was blocked and no local scientific assets were missing. Package-path/startup warnings and the existing model no-damping warning occurred without preventing verification. Full nonlinear qualification, fresh-process full restart, performance measurement and production campaigns were not run. The unrelated untracked `tools/free-surface-initialization-study/` directory was preserved.

## T4 handoff

Implement dealiased interior and both-boundary QG nonlinear tendencies through the existing physical forcing/projection interfaces. Preserve the thermal generator and strict-source ownership implemented here. Replace the explicit linear-only restriction only when the corresponding nonlinear products are qualified. Retain the shared controller, independent endpoint norms, accepted-state recovery and observation invariance tests; add manufactured conservative nonlinear and Fourier-convolution references before any long run. T5/T6 still own physical drag and closure selection, and T8 owns full persisted continuation.
