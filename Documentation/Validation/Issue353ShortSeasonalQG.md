# Short seasonal QG composition using existing model interfaces

> Current scope: the [adiabatic qualification handoff](Issue353AdiabaticQualification.md) supersedes this report's historical next-work recommendations. Numerical results and failed accuracy criteria below remain unchanged. Thin-layer diffusion research is #389; the long adiabatic application is #367; release/install/export work is #354.

This increment of #353 demonstrates the primary seasonal experiment as a small composition of the existing v4-style interfaces: a transform, registered forcing objects, `WVModel`, ordinary output groups, and `WVModel.modelFromFile`. It adds no runtime class, persistence schema, model hierarchy, or scientific operator. The authoring example uses the resolved APV/endpoint/MDA state throughout. This is a short finite-resolution model qualification; the primary experiment's pins, case directories and saved trajectories are unchanged.

## What the experiment taught us

| Requirement | Existing evidence and retained design | This increment |
| --- | --- | --- |
| Physical initialization | Experiment tests check deterministic seed, zero interior QGPV/MDA, retained Fourier patterns, and forcing conventions. | Reproduce the same physical definitions with explicit endpoint parameters and independent retained counts. |
| Process accounting | Experiment callbacks sum to the model's diagnosed tendency; WVM #348 supplies independent field/inventory checks. | Use `coefficientTendency(excludingForcing=...)` and `quadraticDiagnostics(tendency=...)` directly, avoiding a second forcing-dispatch implementation. |
| Scientific operators | #351 checks strict seasonal forcing and diffusion against independent linear references; #348 checks interacting unforced modes and invariants; bottom-friction tests check drag work. | Exercise all five processes together and quantify changes when each is omitted. |
| Persistence | Experiment tests cover accepted progress, segmented output and interrupted-record recovery; #377 qualifies shared model output. | Use one standard model output file and restore through `WVModel.modelFromFile`, then explicitly reselect exponential stepping. |
| Numerical error | The public seasonal-response assessment separates representation/evolution error; transfer assessment preserves mode identities. | Measure actual timestep refinement at one declared resolved band and restart agreement for aligned and shifted step sequences. |
| Analysis | Experiment spectra and profiles have inventory checks; profiles are normalized before their integral assertions. | Use raw shared reconstruction and canonical inventories. No profile normalization is used as independent accuracy evidence. |

The result is an authoring example, not another experiment-management framework. Long-run scheduling, segmented case recovery, plotting and dependency promotion remain experiment/release concerns. Generic per-process isolation is already possible without changing the forcing registry or adding a new API; evaluating individual processes costs extra reconstructions and is used here for qualification rather than every integration stage.

## Example and reproduction

With compatible authoring dependencies and `Documentation/Examples` on the MATLAB path:

```matlab
model = runShortSeasonalQG('new-short-seasonal.nc');
```

The path must be new. `makeShortSeasonalQGModel` shows all scientific setup explicitly. `runShortSeasonalQG` creates ordinary coefficient/field output, integrates to day 32, closes the file, restores it through `WVModel.modelFromFile`, reselects exponential stepping, and continues to day 64. No `progress.mat`, bespoke checkpoint reader, manual coefficient adoption, repeated seed, or duplicated physical reconstruction is required. The returned model's output file is closed. This authoring example is outside the released MPM payload; released example adoption remains #354.

Run `TestShortSeasonalQG` for focused assertions. `TestShortSeasonalQG.runStudy(outputFolder)` writes the time, restart, mechanism and process-budget CSVs plus two interrupted checkpoints and their uninterrupted reference files. In a fresh process with all InternalModes paths removed, call `TestShortSeasonalQG.verifyRestartWithoutProvider(outputFolder)`. It asserts solver unavailability and continues both checkpoints. This advances those files; rerun the study to recreate them. Add the example directory to the path before running the study.

## Declared case

The physical domain is 500 km square and 4 km deep, at latitude 24 degrees. Stratification is $N^2(z)=(5.2\times10^{-3})^2\exp(2z/1300)$ s$^{-2}$. Endpoint parameters are explicitly $g_0=-\int_{-D}^0N^2\,dz$ and $g_d=+\int_{-D}^0N^2\,dz$; both endpoints are active. The initial bottom anomaly is zero, which does not make that boundary inactive.

The reduced authoring case has `[24 24 65]` samples, 14 retained APV modes, two MDA modes and two endpoint coordinates. These are independently declared resolved counts, not a shared vertical dimension. It starts at time zero with zero interior QGPV and zero MDA. The surface-displacement seed has 1 cm RMS, zero horizontal mean, Fourier wavevectors `[1 0;2 0;3 1;4 -1;1 2;2 -2]` and phases `[0.1 1.3 2.2 0.7 2.6 1.8]`. Construction rejects grids that omit any seed wavevector or seasonal mode 5 after dealiasing.

The source is the experiment's strict surface endpoint-displacement tendency

$$\partial_t b_0=\frac{10\pi}{T}\sin(10\pi y/L_y)\sin(2\pi t/T),\qquad T=365.25\times86400\ \mathrm{s}.$$

It has no direct interior QGPV or MDA tendency. Its physical buoyancy tendency is $-N^2(0)\partial_t b_0$; it is not the optional weak buoyancy-flux source. Other registered processes are nonlinear advection, quadratic bottom drag with `Cd=1e-3`, default `WVAdaptiveDamping`, and vertical diffusivity `kappa_z=1e-5` m²/s. The example uses six-hour nonadaptive exponential steps; all reported time-refinement cases set both `initialStep` and `maximumStep` explicitly and inspect `exponentialStatistics.acceptedStepSeconds`.

## Time refinement and meaningful evolution

Runs end at day 64. The refined reference uses one-day exponential steps in the same resolved space. Every accepted step equals the requested 8-, 4-, 2- or 1-day interval, with respectively 8, 16, 32 and 64 accepted steps. This verifies actual time refinement rather than assuming that tighter adaptive tolerances change a nonadaptive calculation.

| Step (days) | Positive physical energy-norm state error | Sampled QGPV relative error | SSH relative error |
| ---: | ---: | ---: | ---: |
| 8 | `4.9307e-8` | `1.2566e-5` | `8.4700e-9` |
| 4 | `2.9821e-9` | `7.6090e-7` | `5.1764e-10` |
| 2 | `1.7206e-10` | `4.3939e-8` | `3.0065e-11` |

The energy-norm error is $\sqrt{E(A-A_\mathrm{ref})/E(A_\mathrm{ref})}$ using positive physical energy with cross terms. Sampled field errors are flattened Euclidean relative norms on this fixed grid. QGPV errors decrease by about a factor of sixteen with each timestep halving. The one-day reference is a refinement estimate, not a certified exact solution. The regression requires decreasing errors and at least a twentyfold improvement from eight to two days.

The complete case reaches speed greater than 0.01 m/s and nonzero interior QGPV, while maintaining exactly zero MDA. Omitting one process at a time for the same 64-day interval and two-day steps gives:

| Omitted process | Positive physical energy-norm difference | Sampled QGPV relative difference |
| --- | ---: | ---: |
| Nonlinear advection | `1.9489e-3` | `2.5823e-3` |
| Seasonal source | `9.9997e-1` | `9.9996e-1` |
| Quadratic bottom drag | `1.7329e-8` | `3.5205e-7` |
| Adaptive damping | `3.5982e-4` | `8.7898e-2` |
| Vertical diffusivity | `2.0429e-3` | `1` |

These are mechanism sensitivities, not numerical errors. All process tendencies are nonzero at the final state, but bottom drag is weak for this surface-seeded short case. The dedicated drag-work controls remain necessary evidence for that operator. The omission comparison shows that diffusion dominates interior QGPV production in this selected control; the strict seasonal source itself has no direct interior QGPV tendency. Removing the source changes the physical problem; no shortened artificial seasonal period or amplified seed is used to manufacture activity.

Each process's physical/generalized-energy, enstrophy and endpoint-variance rates are recorded in `issue-353-process-budgets.csv`. Their coefficient tendencies and rates sum to the complete model evaluation within `1e-12` relative to the appropriate total or sum-of-absolute-rate scale. This is a dispatch/accounting test; it does not claim independent validation of the shared diagnostic formulas. The independent #348/#351 and drag tests supply that foundation. Signed generalized energy is normalized using $E+|g_0|B_0+|g_d|B_d$, avoiding cancellation in its signed value.

## Complete-model restart

Restart controls use two-day steps and stop at either day 32 (aligned) or day 31 (shifted step sequence). Coefficients plus SSH, QGPV and displacement are written daily; a second Eulerian group writes velocity and SSH every three days starting at half a day. The final files have 65 coefficient records and 22 diagnostic records. The second schedule deliberately exercises intermediate output reconstruction.

| Checkpoint day | Maximum state/inventory relative error | Maximum saved-output relative error |
| ---: | ---: | ---: |
| 32 | `2.0742e-12` | `5.2171e-14` |
| 31 | `8.0184e-9` | `3.5683e-9` |

The state comparison includes every coefficient family, reconstructed velocity/displacement/SSH/QGPV, both endpoint anomalies and every quadratic inventory. Persisted forcing configuration, selected scientific operators and time are compared exactly, treating corresponding NaNs as equal. Numeric relative norms use the reference norm bounded below by `realmin`; signed generalized energy uses the positive scale above. Output comparison includes all time-dependent stored payloads and identical time vectors. The declared continuation tolerance is `1e-6`; the shifted-step control meets it without assuming bitwise continuation. Fresh-process provider-free results are recorded in verification below.

## Scope and remaining gates

This increment establishes the short coupled composition and standard-file restart, using existing idioms and no runtime changes. It does not qualify the custom experiment runner's progress/segment recovery against a new dependency graph, promote its pins, or alter saved runs. It does not establish continuum seasonal accuracy at 14 APV modes: #351 demonstrates why accurate energy and small time errors can coexist with significant unresolved QGPV error. The chosen modal bandwidth is intentionally explicit.

Broader spatial/retained-band refinement, observable-specific seasonal resolution assessment for the intended experiment resolution, and dependency promotion remain visible #353/release follow-ups. Resolution-dependent damping must be distinguished from numerical convergence. The three-cycle/long experiment is #367; released corrected-provider, installed/exported examples and full scientific CI remain #354. No nonlinear Boussinesq, integrated exponential particle/tracer stepping, or new universal error target is implied.

## Verification

All four new test cases and 32 affected regressions passed on MATLAB R2025b Update 4, covering exponential diffusion integration, quadratic bottom friction, seasonal response assessment, and ordinary output persistence. The time-study fixture initially used an invalid empty-structure assignment; correcting it required no runtime change. Both aligned and shifted checkpoints continued in a fresh MATLAB process with InternalModes unavailable, reproducing the state/output errors above. The six-hour example executed through day 64 and wrote 65 records. Code Analyzer returned no findings for the new test and both example functions. Documentation generation/check passed with 2358 files, 4819 routes and no generated drift. Only the generated version history changes; authored website scope is unchanged. Whitespace and package-metadata scope checks pass. No task assets are missing. WVM baseline: `25de3c78774b0e31b54aca48136d6617b26804ab`; scientific construction uses corrected InternalModes authoring commit `e7ea60dadc4e947769cda89f7c1116f22ffa404b`. The example is derived from the experiment's inspected `e4ca4e9f2c41a3e5b481fe3f20821b77630bcc4f` configuration. No manifests, dependency versions or released package snapshots change.
