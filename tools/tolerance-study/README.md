# Bounded v5 adaptive-tolerance comparison

The current implementation, recommended settings, and final checks are in the [production qualification report](production-qualification.md). The comparisons below retain their original experimental settings and results.

## Decision

The invariant candidate improves the QG boundary cases at some matched costs. The short mixed Boussinesq case does not discriminate between the policies: identical trajectories and RHS counts do not justify preferring energy scaling for the balanced families. The implemented production energy path remains a working baseline; selecting the balanced-family policy still requires an evolving balanced Boussinesq comparison. A benefit in QG need not produce a whole-model speedup when another family controls the shared step.

The new production path is ordinary `WVModel(wvt)` with `setupIntegrator(integratorType="adaptive",absTolerance=1e-6,relTolerance=1e-3)`. Fixed stepping and existing v4/QG defaults remain available and unchanged. The tolerance arrays account for independent mode counts, inactive wave padding, Fourier multiplicities, and real horizontal means. Initial steps use actual retained wave frequencies, the inertial frequency, and physical velocities.

## Experiment

`runTolerancePolicyStudy(outputFolder)` compares energy and invariant arrays through the same WVModel/ode78 solver. The invariant candidate replaces APV energy weights with potential enstrophy and zero-APV weights with endpoint anomaly variance. Each dimensional family scale is calibrated to match the energy coefficient tolerance at the first retained mode/column; it is not matched at every wavenumber. Other families retain energy weights. This calibration is fixed across the sweep, and stored with each reference.

The three cases are the zero-APV ellipse at `[64 64 65]` for two `L/U`, the same ellipse with a nonparallel APV mode at comparable horizontal kinetic energy, and the documented mixed-family nonlinear Boussinesq initial state at `[8 8 129]` for 200 seconds. The QG comparison intentionally holds one spatial discretization fixed; its time errors are not continuum errors. The separate 128-point vortex figure has its own spatial qualification.

Time references use energy scales and relative tolerances `1e-11` and `1e-12`; their discrepancy must be below `1e-5`. Candidate absolute-scale multipliers are `1e-2,1e-3,1e-4`, extended once to `1e-1` because the original sweep did not bracket the QG `1e-3` target. Relative tolerance is `1e-9`. Both policies use `MaxStep=duration`: the MATLAB default duration/10 cap initially made all short QG trials identical, masking tolerance effects. Production keeps MATLAB's ordinary cap.

Errors are discrete relative RMS/L2 field errors at final time in complete PV, velocity, displacement and both boundary anomalies. Quantities with reference norm below `1e-12` use maximum absolute error, explicitly including the identically zero PV control. The main comparison takes the maximum of the nonzero relative field errors; the zero-PV absolute check is separately reported. No claim is made that the discrete vertical sampling norm equals the continuum energy norm. Physical invariant budgets and significant-wave phase errors are also recorded; phases exclude coefficients below `1e-6` of each family's largest amplitude.

## Results

The [27-row summary](summary.csv) includes all trials, solver accepted/rejected steps, RHS counts, phase errors, and budget changes. Representative matched-cost results:

| Case and scale | Energy error / RHS | Invariant error / RHS |
| --- | ---: | ---: |
| Boundary, `1e-3` | `2.56e-4 / 52` | `5.34e-5 / 52` |
| Mixed QG, `1e-4` | `8.62e-6 / 65` | `1.16e-6 / 65` |
| Boussinesq, `1e-2` | `5.93e-8 / 39` | `5.93e-8 / 39` |

The Boussinesq interval is easy enough that even the loosest trial remains well below `1e-4`; it does not establish a tolerance-performance boundary for long or energetic Boussinesq runs. The independent manufactured forced-wave tests exercise source integration over longer intervals and compare against an exact coefficient solution. Error need not decrease at every adjacent setting because accepted-step sequences change; the tighter QG trials show a substantial reduction, while all Boussinesq trials are already below the target.

Practical energy settings `1e-6 / 1e-3` give maximum field errors `1.93e-8`, `1.60e-8`, and `1.78e-9` for boundary, mixed QG, and Boussinesq respectively. The Boussinesq significant-wave phase error is `1.88e-5 rad`. Its phase and field errors are measured against the tighter reference, not inferred from conserved energy. The mixed-QG physical-energy change is approximately `-8.70e-5`; the reference shares the represented dynamics, and time refinement does not imply exact physical-energy conservation.

The preliminary and final matched Boussinesq timings agree with the identical RHS counts; no runtime benefit is attributed to subsecond timing differences. There is no basis here to promise the same accuracy in untested regimes or to transplant energy-scale numbers into invariant units.

## Weakening-wave follow-up

`runWaveWeakeningStudy(outputFolder)` repeats the 200-second Boussinesq comparison at initial wave-amplitude factors `1,0.1,0.01,0`, corresponding to wave-family energy fractions `1,0.01,0.0001,0`. Only `Aw_p` and `Aw_m` change; APV, boundary, inertial, and MDA coefficients remain fixed. Dimensional family calibrations also remain fixed. Both policies use the same `InitialStep=6` seconds and `MaxStep=duration`, so the amplitude-dependent production starting-step estimate cannot confound the comparison. The three absolute scales and common `R=1e-9` are unchanged.

The [24-row results](wave-weakening.csv) include the two time references for each amplitude. At absolute scale `1e-3`, the policies give identical results:

| Initial wave amplitude | Initial wave energy fraction | RHS / accepted steps, either policy | Maximum field discrepancy |
| ---: | ---: | ---: | ---: |
| 1 | 1 | 52 / 4 | `1.20e-8` |
| 0.1 | 0.01 | 52 / 4 | `8.58e-10` |
| 0.01 | 0.0001 | 39 / 3 | `3.14e-10` |
| 0 | 0 | 39 / 3 | `3.95e-14` |

All 24 trials have zero rejected steps. Policy pairs are identical at every scale, and all three scales give identical results at amplitude `0.01` and zero. Reference discrepancies are at most `1.45e-11`; the zero-wave discrepancy is at the reference/roundoff level and should not be interpreted as measured accuracy to fourteen digits.

Weaker waves reduce work, consistent with waves contributing to step selection. This does not identify the controlling coefficient family directly. More importantly, removing waves does not expose a demanding balanced problem in this initial condition: APV and boundary coefficients occupy one common horizontal wavevector, while the nonparallel component is in the waves. At zero initial wave amplitude this short run is extremely easy. Thus this experiment neither rejects invariant scaling nor establishes its benefit in Boussinesq. The subsequent [evolving balanced Boussinesq comparison](evolving-balanced-comparison.md) runs a boundary vortex with nonparallel APV for one advective time and directly records each family's normalized local error. It also audits the absolute and relative branches: wave control in these tests is conditional on the chosen absolute wave-energy budget, not proof that this budget is optimal.

Run with `runWaveWeakeningStudy(fullfile(tempdir,'v5-wave-weakening'))`. Raw states, reference fields, fixed scales, and budgets for this run are in `/tmp/wv-tolerances/wave-weakening`; only the compact CSV and driver are retained here. This follow-up changes no production settings.

## Reproduction and verification

Use MATLAB R2026a with the WVM v5 authoring graph and InternalModes beta.4 (`f2ce3c1`). The active provider checkout lacked `assessModeConvergence.m`; this run used an extracted beta.4 tree without changing that checkout. The WVM manifest already declares beta.4.

```matlab
addpath('tools/tolerance-study');
runTolerancePolicyStudy(fullfile(tempdir,'v5-tolerance-study'));
summarizeToleranceStudy(fullfile(tempdir,'v5-tolerance-study'));
```

Raw runs, reference fields, dimensional scales and budgets live in the caller's output directory; the delivered run used `/tmp/wv-tolerances/final-comparison`. Only this compact report, CSV, and reproducible drivers belong in the source tree. The candidate override is experiment-local and is not a second production API.

Verification ledger: seven focused test methods passed across `TestFreeSurfaceAdaptiveIntegration` and the affected manufactured/adaptive methods of `TestFreeSurfaceBoussinesqEvolution`. These cover unit energy weights, zero flow, absent families, variable wave counts, nonlinear damping/restart, and constant/variable-stratification prescribed sources and restart. The documented adaptive nonlinear example completed and wrote 11 NetCDF times. Code Analyzer completed without findings in the touched/new code; the mean-indexing suggestion was corrected and its normalization test rerun. One documentation build and one check passed (2,364 files, 4,831 routes, zero failures or drift). The note compiled without warnings and both PDF pages were inspected. Source-scope, manifest, generated-artifact, and whitespace checks passed. No package snapshot or manifest was changed; this is authoring-graph qualification, not a release/export qualification.

Follow-up verification: all 24 weakening-wave trials and eight reference integrations completed. Code Analyzer found no issues in `runWaveWeakeningStudy.m`; the revised two-page note compiled without warnings and was visually inspected. Diff/whitespace checks passed. No production MATLAB code or generated website sources changed in this follow-up, so the previously successful model tests and website check were not repeated.
