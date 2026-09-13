# Production v5 adaptive tolerances

The recommended v5 policy is `tolerancePolicy="family"`, with `absTolerance=1e-6` and `relTolerance=1e-3`. Existing calls retain `"energy"`; no v4 or QG default is changed.

```matlab
model.setupIntegrator(integratorType="adaptive",tolerancePolicy="family", ...
    absTolerance=1e-6,relTolerance=1e-3);
```

The coefficient observer uses potential enstrophy for `Ag_q`, separate endpoint displacement invariants for `Ag_0`, and positive reference-geometry energy for `Aw_p`, `Aw_m`, `Aio`, and `Amda`. Every family retains the local radial-bin allocation. The horizontal-mean allocation uses the clipped zero bin and the real/complex unit-coefficient energy. Empty bins and inactive wave padding do not consume a physical error allocation.

`pvAbsTolerance`, `surfaceAbsTolerance`, and `bottomAbsTolerance` optionally override the three invariant scales. They must be positive finite scalars, or empty for automatic calibration, and require the family policy. Automatic calibration sets A_I=A_E sqrt(C_ref/TE_ref), at the first retained APV mode and lowest retained nonzero horizontal wavenumber, separately for each active endpoint. It depends only on reference geometry. PV scale units are m/s; endpoint displacement scale units are m^(3/2). Multiplying by the endpoint reference N² converts a displacement scale to the corresponding buoyancy convention. Changing coefficient normalization does not change the physical floor; changing the dimensional scale does.

Policy and automatic/explicit scale choices are saved with the coefficient observer and restored into the model's canonical observer. `setupIntegrator` retains these coefficient settings when omitted, including after restart; select the desired relative tolerance when configuring the resumed solver. Historical scalar-only files reconstruct the energy policy. Family settings apply to ordinary componentwise adaptive stepping, not the cell solver's RMS/additive criterion or fixed-step/exponential solvers.

## Evidence and decision

The [original comparison](README.md) improved QG boundary errors at some matched costs. The [evolving Boussinesq study](evolving-balanced-comparison.md) then held balanced coefficients and physical tolerance budgets fixed while reducing initial wave amplitude. Its policy pairs had identical trajectories and RHS counts: generated waves controlled the shared step even at zero initial wave amplitude. The branch audit found the controlling coefficient on the absolute branch in all 803 attempts at both R=1e-9 and R=1e-3.

These results support the balanced-family choice without requiring a speedup in a wave-controlled Boussinesq case. They do not optimize the wave-energy budget or equate controller dominance with physical significance. The recommended settings remain conservative starting values. Weak generated wave phases are not all resolved by a bulk-field target.

## Production-setting qualification

`runProductionToleranceQualification` exercises the public API without overriding solver tolerances or using an instrumented solver. The surface case reuses the evolving 32×32×65 mixed-family vortex and its independently tightened saved reference. The bottom counterpart uses 16×16×65, g0=Inf and gd=0.1, with an inward bottom mean displacement and the same Rossby number and nonparallel APV/wave construction. Both evolve for one L/U. These are time-integration checks at fixed spatial resolution.

The required checks are maximum relative RMS error below 1e-3 across boundary anomaly, PV, velocity and displacement; lower error at absolute scale 1e-7 than 1e-6; and independent reference discrepancy below 1e-4. Boundary denominators remove the reference mean while retaining mean error in the numerator. Quantities with vanishing reference norm use absolute errors. Positive quadratic error norms include reconstructed cross terms; energy-budget drift is recorded separately. Timings are descriptive because qualification jobs may overlap; RHS counts are the stable cost measure.

| Case | Absolute scale | Maximum field discrepancy | Reference uncertainty | RHS evaluations |
| --- | ---: | ---: | ---: | ---: |
| surface | 1e-06 | 7.06e-06 | 9.66e-06 | 20,306 |
| surface | 1e-07 | 7.55e-07 | 9.66e-06 | 43,823 |
| bottom | 1e-06 | 2.45e-06 | 1.23e-07 | 15,951 |
| bottom | 1e-07 | 5.57e-07 | 1.23e-07 | 32,864 |

All four runs pass. The [complete CSV](production-qualification.csv) retains individual errors, positive quadratic norms, phase, budgets and timings. The surface reference uncertainty exceeds the smaller trial discrepancies, so those discrepancies must not be interpreted as certified sub-micro relative accuracy. Both cases satisfy the 1e-3 target with margin. `wavePhaseError` measures the largest reference `Aw_p` coefficient; it does not certify phases of weak coefficients.

At the recommended settings the surface boundary field changes by 22.1% and the bottom field by 13.3%. Positive quadratic error norms are 3.59e-7 and 1.37e-7 respectively; the separate nonlinear energy-budget changes are 4.29e-7 and -3.41e-7. These budgets are diagnostic, not the acceptance criterion.

The [four-panel QG boundary-vortex figure](../../Documentation/Validation/BoundaryVortex/README.md) is independently qualified in time and horizontal/vertical sampling. Its maximum displayed spatial discrepancy is 7.86e-4. The coarser Boussinesq controller figure is a time-stepping diagnostic, not a spatial-convergence claim.

## Reproduction

Use MATLAB R2026a and the WVM authoring graph with InternalModes beta.4 (`f2ce3c1`). The local provider checkout lacks `/Users/jearly/Documents/OceanKitRepositories/internal-modes-evp/assessModeConvergence.m`; these runs use the extracted beta.4 tree at `/tmp/wv-tolerances/provider`. No installed package or snapshot is modified. This qualifies the authoring graph, not a release/export or clean installation.

```matlab
addpath('tools/tolerance-study');
runProductionToleranceQualification(fullfile(tempdir,'v5-production-tolerances'));
```

To reuse the surface reference, provide `surfaceReferenceFolder` pointing to a completed `runEvolvingToleranceStudy` output with amplitude 1. The driver checks exact initial-state agreement. Use a fresh output directory after model or dependency changes. Raw qualification states remain outside the source tree; commit only this report, the compact CSV and reproducible drivers. Historical controller instrumentation generates a temporary solver copy outside the repository; production uses the installed `ode78` directly.

Implementation: [5b264193](https://github.com/JeffreyEarly/wave-vortex-model/commit/5b264193). Raw closeout runs are in `/tmp/wv-tolerances/closeout-surface`, `/tmp/wv-tolerances/closeout-bottom`, and `/tmp/wv-tolerances/closeout-example`.

Tracking: [boundary figure #516](https://github.com/JeffreyEarly/wave-vortex-model/issues/516), [production integration #517](https://github.com/JeffreyEarly/wave-vortex-model/issues/517). Broader precision research #165 and beta delivery #354 remain separate.

## Verification ledger

Seventeen focused test cases pass across the adaptive-integration tests and affected manufactured-source tests (including parameterized energy/family runs). Coverage includes unit physical energy and radial allocation, basis-rescaling invariance, independent endpoint overrides, historical scalar-only persistence, family configuration restoration, real MDA, absent waves/endpoints, unequal wave counts, mean-only grids, finite zero-flow steps, prescribed sources under constant/exponential stratification, and nonlinear advection with adaptive damping and restart. These exercise the applicable registered Boussinesq forcing inventory: prescribed volume source, nonlinear advection, and adaptive damping.

The updated `runNonlinearFreeSurfaceBoussinesq` example completed with the public family policy and wrote all 11 NetCDF output times.

Code Analyzer was run on changed/new MATLAB files. New findings were corrected; existing array-growth and unused-input advisories in the model/output-group classes remain outside this change. The documentation build and check passed with 2,368 files, 4,839 routes, zero failures and zero generated drift. The companion note is two pages, compiled without layout warnings and visually inspected. Diff/whitespace and repository-scope checks exclude the main manuscript, dependency manifests and released snapshots.
