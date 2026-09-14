# T5: physical forcing and shared process evaluation

Implemented against WVM `875ac2ecc698141b26b00a1f96b532474c25b8ec` on `implementation/balanced-diffusion-m2`, with the concurrent T5–T8 integration changes. The scope is [issue #436](https://github.com/JeffreyEarly/wave-vortex-model/issues/436) and the [milestone integration audit](../../Architecture/BalancedDiffusionMilestone2Audit.md). These controls qualify physical forcing connections and short trajectories; the historical 257/385-direction seasonal linear qualification remains in force and is not replaced by these smaller manufactured tests.

## Decisions and implementation

`WVBottomFrictionQuadratic` remains the one quadratic drag implementation. Its shared free-surface path evaluates `-Cd*hypot(u,v)*[u,v]` on the existing doubled horizontal grid, then asks the owning transform to project stress. `Cd` accepts finite nonnegative values, including zero. The portable declaration remains unavailable for both free-surface QG representations; legacy supported paths keep their existing declarations.

Both QG peers now implement `boundaryStreamfunction(endpoint)`, returning one compact nonzero Fourier row in m2/s. APV evaluates only the selected rows of its APV and zero-APV maps; thermal evaluates the endpoint Legendre trace against the canonical thermal-to-polynomial map. Neither reconstructs a volume for drag.

The thermal stress adapter follows the physical-energy weak form. With `curlHat = i*k*tauYHat - i*l*tauXHat`, endpoint polynomial trace `p_e`, and the stored thermal `sourceDual`,

$$\dot A_{\mathrm{th}} = -\mathrm{sourceDual}\,p_e\,\widehat{\mathrm{curl}\,\tau},\qquad \dot A_{\mathrm{mda}} = 0.$$

Periodic integration gives `-mean(psi*curl(tau)) = mean(u*tauX+v*tauY)`. The positive thermal energy metric already includes the free-surface term. Therefore physical energy work equals the stress work directly; no signed APV endpoint-weight adjustment belongs in the thermal energy. Both active endpoint equations respond through the complete balanced inverse. Stress is not placed in a top/bottom volume cell and creates no horizontal-mean tendency.

Both QG `coefficientTendency` methods optionally return `processes.labels` and an ordered row `processes.tendencies`. The normal path still projects combined spatial sources once. Requesting budgets separately projects actual spatial callback increments and records actual before/after spectral increments, preserving registry priority, exclusions and order-dependent callbacks. Thermal homogeneous diffusion is labeled `density diffusion`. Damping subcomponents use the same callback worker and labels ending `: horizontal` and `: vertical`. No diagnostic pass changes coefficients or the clock.

Thermal nonlinear advection returns its tendency and speed from one qualified product-grid calculation at its registered forcing position. Physical-state structures no longer carry coefficient tendencies. Drag and seasonal sources avoid native-volume reconstruction; unknown physical callbacks trigger one lazy native tuple. No persistent stage cache or additional model/forcing hierarchy was introduced. Root integration owns the energy/component correction and shared physical metrics, documented in [T7 validation](../Issue438/README.md).

## Scientific controls

`TestThermalForcing` constructs constant and exponential controls with domain 500 km square, depth 1000 m, grid 16 by 16 by 65, 17 complete thermal directions, four MDA directions, and separately qualified nonlinear quadrature. These are finite-space interface controls, not a claim of adequate bandwidth for the 4000 m seasonal campaign.

The source test samples the actual annual mode-5 horizontal pattern at four absolute times for both prescribed magnitudes M=10 and M=100, with amplitude `M*pi/(365.25*86400)` in m/s. It separately samples phase 0.7 and period 100000 s. The forcing contributes exactly zero native interior and bottom sources. For a zero-diffusion constant-stratification mode-1 control at amplitude 1e-7 m/s, projected surface and bottom displacement errors are below 1e-12 m/s, and reconstructed direct QGPV leakage is below 1e-14 s-2. The mean source is checked below 1e-22 m/s. T3's exact seasonal evolution controls continue to own cumulative source/clock qualification.

Manufactured nonparallel bottom velocities exercise both endpoints, arbitrary complex stress, the weak map and physical work. Independent 1025-point physical-depth quadrature includes kinetic energy, interior potential energy and free-surface potential energy separately in its integrand and agrees with the stored metric contraction at relative tolerance 1e-10. Potential enstrophy is independently contracted from reconstructed full QGPV and its tendency.

| Stratification | Thermal quadratic stress power (m3/s3) | Independent 8x-grid power (m3/s3) | Relative stress error | Enstrophy rate (m/s3) |
| --- | ---: | ---: | ---: | ---: |
| Constant | -6.727118543727328e-8 | -6.727117719233477e-8 | 1.23e-7 | 5.79e-32 |
| Exponential, scale 1300 m | -6.727118543727327e-8 | -6.727117719233477e-8 | 1.23e-7 | -8.10e-29 |

The negligible enstrophy rates for this manufactured boundary load are retained as signed results, not relabeled as dissipation. The declared doubled-grid power allowance was 5e-4 relative, the 4x/8x reference power difference allowance 1e-5, and the refined coefficient difference allowance 2e-4. All pass. The square-root speed law has not been called exactly alias-free. Existing APV tests continue to check their signed generalized work separately.

`qualifyThermalForcing` evolves nonparallel manufactured states with advection and kappa_z=1e-5 m2/s to 20000 s. For each stratification it evaluates four cases: neither external process, seasonal source only, drag only, and both. The source uses mode 1, amplitude 1e-5 m/s, phase 0.7, period 100000 s; Cd=1e-3. Fixed steps 2000 and 1000 s are compared with a 500 s reference in five physical RMS norms. The declared fine-step relative allowance was 1e-5 with at least fourfold refinement improvement unless already below 2e-11. Actual fine errors range from 7.12e-11 to 1.50e-10, with about seventeenfold improvement. See [time-refinement.csv](time-refinement.csv); mechanism bit 1 selects source and bit 2 selects drag.

[mechanism-omissions.csv](mechanism-omissions.csv) retains physical effects of each omission, relative to initial-state RMS norms. Omitting source changes surface displacement by 0.135–0.193%; omitting drag changes speed by 0.973–1.028% and bottom displacement by 0.567–1.714%. Thus each required process acts in the combined nonlinear trajectory. These runs do not select damping, qualify long-time seasonal turbulence, or measure campaign performance.

## Verification ledger

Every numerical command used MATLAB R2026a Update 4 (`26.1.0.3312084`), `maca64`, double precision, two computational threads, and a clean path configured through `configureCIEnvironment`. Unique `IMInternalModes` resolution was verified inside `OceanKit/InternalModes-2.0.0-beta.4`, tag revision `f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`. Loaded dependency snapshots: SplineCore 2.2.0, Distributions 2.0.0, chebfun 5.7.0, NetCDF 1.0.2, ClassAnnotations 1.2.1. No snapshot, package version, historical qualification or experiment pin changed.

The launchers first ran the following setup from the workspace root, removing older sibling authoring paths introduced by MATLAB startup:

```matlab
restoredefaultpath;
workspace='/Users/jearly/Documents/OceanKitRepositories';
cd(fullfile(workspace,'wave-vortex-model')); addpath('tools');
configureCIEnvironment(pwd,fullfile(workspace,'OceanKit'));
p=string(strsplit(path,pathsep));
bad=startsWith(p,string(workspace)+"/") & ~startsWith(p,string(workspace)+"/OceanKit/") & ~startsWith(p,string(workspace)+"/wave-vortex-model");
if any(bad), rmpath(char(join(p(bad),pathsep))); end
assert(contains(string(which('IMInternalModes')),'OceanKit/InternalModes-2.0.0-beta.4'));
assert(numel(which('IMInternalModes','-all'))==1);
maxNumCompThreads(2);
```

| Command after setup | Result |
| --- | --- |
| `runtests({'UnitTests/TestThermalForcing.m','UnitTests/TestFreeSurfaceQGBottomFriction.m'})` | All seven methods pass, with the previously failing source/configuration method rerun after the shared snapshot fix. The three APV methods cover active/inactive endpoint combinations, work and restart. |
| `runtests({'UnitTests/TestForcingLifecycle.m','UnitTests/TestPortableForcingContracts.m'})` | 12/12 pass, including legacy hydrostatic/nonhydrostatic/barotropic laws, ownership, ordering, conversion, annotated configuration and portable declarations. |
| `qualifyThermalForcing` | Eight refined trajectory cases and four omission comparisons pass; CSV outputs committed beside this document. |
| `checkcode(file,'-id')` for 11 added/changed T5 MATLAB source/test/helper files | No new findings. Two pre-existing unused-input findings remain in `WVNonlinearAdvection`. |
| `git diff --check` | Pass for the coherent implementation batch. Root integration owns the final documentation build/check and complete milestone regression gate. |

Transient setup failures are retained here: the first process-order fixture assigned priority 200 while ordinary drag uses 255; changing the fixture to the same default priority correctly exercised its later registered position. A first qualification launcher initialized an empty structure without the result fields and failed while assembling its report, after the simulations; explicit result fields fixed it. The direct snapshot test exposed missing `t0`/`forcing` annotations and then missing `x`/`y` required dimensions; the shared T8 integration corrected those omissions. Same-grid seasonal conversion now preserves the exact original pattern after validation. One targeted test launcher selected zero methods; it was replaced with an explicit nonempty name selection before claiming a pass. No missing scientific assets or blocked T5 checks remain.

## Final integration audit

The shared stage-speed contract is explicit: a speed supplied in `physicalState.uvMax` is authoritative. The thermal RHS uses the qualified nonlinear product-grid speed when advection is active, regardless of whether another callback requests native fields. A closure-only linear RHS instead establishes the native speed once and returns it to the exponential controller; it must not report zero while applying nonzero damping. Direct standalone damping calls without a supplied stage speed retain native `uvMax` as their documented fallback. No new public transform abstraction was added for this distinction.

The additional `TestThermalDamping/closureOnlyStageSpeedAndZeroCallback` passes. It verifies a nonzero closure-only speed and bound, and unchanged nonlinear tendency/speed after inserting an identity callback whose instrumented native reconstruction reports a 100-times-larger velocity. The existing T5 process test also passes with this stronger reconstruction counter. The initial regression launcher attempted to set protected forcing priority from the test; fixture constructor configuration corrected the test setup before the passing run.

Independent T7/T8 review found one representation mismatch: transfer used an inverse polynomial approximation of physical depth for MDA interpolation, while diagnostics used the exact thermal WKB coordinate. In the 4000 m exponential profile with 33 native samples, the interpolation matrices differed by 6.79e-7 relative and an eighth-degree coordinate polynomial differed by 3.99e-7. Both now use the narrow `WVInternal.thermalVerticalInterpolation` helper, and transfer reuses its source/target matrices for state fitting and error assessment. The independent 33/65-sample deep-profile polynomial regression passes a 2e-12 absolute gate. This does not change the scientifically different APV interpolation helper.

The reader audit also identified ignored invalid scalar-snapshot time indices. T8 now requires index 1 or Inf for scalar thermal snapshots and integer-or-Inf selection generally. T8 owns that fix and its regression. Full metrics, mean factors, Fourier conjugate counting, family/component selections, physical transfer error norms and shared reader ownership otherwise required no additional hierarchy or duplicated physical computation.
