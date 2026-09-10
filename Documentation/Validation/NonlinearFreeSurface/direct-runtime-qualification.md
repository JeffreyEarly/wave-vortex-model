# Direct manuscript runtime qualification

The nonlinear free-surface Boussinesq callback now implements the manuscript projected-amplitude equation `dA/dt = S - Pi[N+P]` through the existing WVM forcing and integration lifecycle. The retained state consists exclusively of the six resolved adiabatic families, including independently retained wave prefixes at each kappa.

## Implementation and removals

`WVNonlinearAdvection` evaluates Appendix C using reconstructed modal pressure, including pressure in `H` inside vertical advection. `coefficientTendency` sums hatted equation sources and calls `projectSources` once. Complete linear dynamics remain in the modal phases. Physical prescribed sources include the horizontal-to-vertical coordinate coupling once; reference sources retain their declared hatted meaning.

The weak solver, mass and reference factorizations, reconstruction adjoint, constraint and Schur operators, real-coordinate solver layout, pressure solver, nonlinear solver context and `fullPressure` API have been deleted. Their dedicated tests and executable historical comparison solvers have also been removed. Measured reports remain labelled historical, with their source links pinned to the pre-replacement revision. There is no fallback path or migration alias.

The ordinary pressure variable is `p`, from modal reconstruction. The unreleased `p_linear` and `p_full` names are removed. Parcel thermodynamics use upper-constant reference density above physical height zero. The surface pressure approximation and energy are `rho0*g*ssh` and `g*ssh²/2`, respectively. Modal pressure is a quadratic-order approximation, not a full nonlinear pressure recovery.

`physicalEnergy`/`totalEnergy` remain quadratic. `nonlinearEnergy` uses moving-volume kinetic energy and parcel APE. Optional RHS diagnostics distinguish the actual resolved `energyTendency` from unprojected `prescribedWork`; no exact finite-dimensional conservation is imposed. Native files store the new explicit field convention, canonical operators, counts, coefficients, clocks and forcing inventory.

## Verification ledger

- The thermodynamic analytic controls, independent Cartesian Appendix C controls, continuous modal-source quadrature/complete-linear controls and manuscript physical-budget diagnostic controls pass: 21 cases. The complete-linear normalized residuals are 1.19e-14 and 6.00e-17 for the two inventories.
- Eleven focused forcing/evolution cases pass cumulatively after correcting two obsolete expectations and rerunning those methods. They cover pipeline agreement, quadratic scaling, ragged/zero-wave pages, source coordinate mapping and absolute clocks, forcing decomposition, physical-volume energy and its directional derivative. Study-vs-runtime comparisons test wiring and analytic versus represented thermodynamics; the independent Cartesian and Gaussian controls above test equations and projection.
- The analytic energy rate is 1.163683883175122e-6 m³/s³ in the mixed fixture. Centered time/state differences at 1 and 0.3 s have relative errors 7.94e-5 and 7.13e-6; their 11.14-fold reduction agrees with second-order differencing. Prescribed work is checked against direct physical integration.
- The [example](../../Examples/runNonlinearFreeSurfaceBoussinesq.m) completes 200 s and eleven native output records. Its relative physical-energy change is -1.132e-8, with minimum parcel-label margins 1.80 m at the top and 1.90 m at the bottom. The [CSV](direct-runtime-example.csv) and [visually reviewed figure](direct-runtime-example.png) show energy, actual rate and margins, not solver residuals.
- Six physical-contract/native-restart cases pass, covering `p` operations and cache invalidation, physical geometry, component additivity, forced evolution and particle/tracer continuation. A separate fresh-process write/read test restores ragged wave counts `[3,2,0,3]` with no InternalModes provider available. [Coefficient, field and energy differences](direct-runtime-cold-restart.json) from uninterrupted continuation are zero. Files with the retired full-C1 convention are rejected.
- All 87 additional [regression cases](direct-runtime-regression.csv) pass in one run: linear/source evolution, output schedules and restoration, count maps and transfer, observer coordinates, forcing lifecycle, operation caches, legacy nonlinear flux and shared resolved contracts. Together with the 21 foundational, 11 focused and six restart/field cases, this is **125 passing cases cumulatively**; it is not a claim to have run every repository suite.
- A temporary native MPM export/install with the declared dependency revisions passes a mixed nonlinear-source, field, energy and native reconstruction consumer. All 528 installed MATLAB files match the current source payload. No authoring study/test functions or retired solvers resolve on the consumer path. Rate, field and energy restart errors are zero; [results](direct-runtime-installed-package.json) record exact package versions. The first harness attempt stopped before scientific use because the authoring checkout was the current directory; rerunning from the isolated consumer directory verifies installed symbol resolution. No version, dependency, release or global registry change was made.
- Production Code Analyzer reports zero blocking findings; all 32 changed MATLAB files have no new correctness findings. Two pre-existing suppressed `NASGU` assignments in `TestFreeSurfaceBoussinesqTransform` were inspected against the baseline and retained because they deliberately warm the variable cache; the generic analyzer labels these unclassified. Remaining changed-file findings are style/performance advisories.
- Documentation build and check pass with ClassDocumentation 1.3.2: 2,362 files, 4,827 routes, no validation failures or generated drift. A read-only independent implementation review found no remaining sign, source-map, energy, ragged-family or persistence defects. Whitespace, scope, unchanged manifest and artifact checks complete the handoff.

## Runtime trajectory comparison

The [qualification driver](../../../tools/nonlinear-study/runDirectRuntimeQualification.m) runs ordinary `WVModel` for 2,000 s, from t=327 s with t0=-17 s, on a 100 km × 100 km × 1 km domain. Each constant/exponential-stratification mixed seed uses 12² horizontal samples, 129 WKB-Chebyshev samples, 8/12/8/8 APV/wave/MDA/inertial modes and both zero-APV boundaries. Three timesteps (10, 20 and 40 s) are compared with the existing study at 10 s using twice the horizontal product samples. The retained inventory is identical.

The [six-row CSV](direct-runtime-trajectories.csv) records all results. On the native grid, the maximum relative per-family RHS difference from the analytic-thermodynamics study is 7.94e-15. At 10 s, final physical checkpoint differences from the padded reference are 2.23e-8 (constant) and 1.87e-8 (exponential). These comparisons use the independent physical/WKB checkpoint norm from the earlier study.

| Quantity at 10 s timestep | Constant N² | Exponential N² |
| --- | ---: | ---: |
| Relative physical-energy change | 4.92e-8 | -1.13e-7 |
| Relative physical APV-squared change | 3.37e-6 | 1.53e-6 |
| Final SSH rate residual (m/s) | 9.57e-10 | 1.96e-9 |
| Final surface-anomaly rate residual (m/s) | 1.23e-7 | 4.38e-7 |
| Final bottom-anomaly rate residual (m/s) | 1.04e-7 | 8.96e-8 |

All runtime stage evaluations satisfy the parcel-label domain check. The energy inventory and its rate agree with independent analytic diagnostics on the same samples within 2.28e-13 m³/s² and 1.05e-17 m³/s³, respectively. This verifies diagnostic semantics, not energy conservation.

The successive timestep differences decrease by factors 9.81 and 8.33 when reducing 40/20 s to 20/10 s. At these already small errors, this does **not** establish clean fourth-order asymptotics for the upper-constant piecewise reference. The prior study's timestep and reference-transition limitations remain relevant. The 10 s runs take about 10.5 s each on this host; warm RHS timing is 0.014–0.038 s in these small fixtures, with concurrent verification jobs running. These timings are a bounded cost observation, not a scaling benchmark.

## Scientific limits

The [boundary/trajectory study](manuscript-evolution-qualification.md) remains the physical resolution evidence. Boundary residuals depend on the retained families; leading coarse-grid APV drift was horizontal truncation. The production callback uses the stored sample grid and the existing antialiasing/count policy. The study's separately padded products do not silently become a new runtime default. Resolution, timestep and label admissibility still require evaluation for the intended experiment. Adaptive and portable nonlinear dynamics remain outside this increment.

## Reproduction and provenance

Validated on 10 September 2026 with MATLAB R2025b Update 4 and the declared InternalModes 2.0.0-beta.4, ClassAnnotations 1.2.1, NetCDF 1.0.2, SplineCore 2.2.0, Distributions 2.0.0 and chebfun 5.7.0 exports. The implementation replaces source revision `7b9ccda7`; the report and CSVs are committed together with the replacement. The unchanged manuscript revision is `311ebf56c13c30ab4cac423ef7260d3bd693e939`.

Configure the ordinary authoring environment, add `tools/nonlinear-study`, and run `runDirectRuntimeQualification(outputFolder)` for the six trajectory comparisons. `runFreeSurfaceNativeRestartCheck("write",outputFolder,dependencyRoot)` and then `"read"` in separate fresh MATLAB processes reproduce the provider-free continuation. The [example](../../Examples/runNonlinearFreeSurfaceBoussinesq.m) writes its own native outputs and figures. Use external output folders; MAT and NetCDF run artifacts are not committed.

Local raw evidence resides in `/private/tmp/wvm-direct-runtime-trajectories`, `/private/tmp/wvm-direct-runtime-example` and `/private/tmp/wvm-direct-mpm-consumer`. The package check uses isolated startup preferences and temporary add-ons; no package is published. No missing local asset prevented completion.
