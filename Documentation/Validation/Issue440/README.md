# T9 thermal APV decomposition qualification

Status: numerical qualification completed on 14 September 2026 against runtime commit `787b90ae`, using MATLAB R2025b Update 5 and InternalModes 2.0.0-beta.5. All declared numerical gates passed. Final branch integration and hosted checks are recorded in [VerificationLedger.md](VerificationLedger.md); no installed snapshot was modified.

## Predeclared gates and independent references

The accepted [T9 design](../../Architecture/Issue440ThermalAPVDiagnosticsPlan.md) fixes relative allowances before these runs: algebraic recomposition and cached/direct agreement `5e-12`; independent coefficient, physical-field and inventory agreement `1e-8`. Independently estimated reference error must be at most `2e-9` of the declared majorant. Physical absolute floors are `1e-13 s^-1` for QGPV, `1e-12 m/s2` for buoyancy, `1e-12 m/s` for velocity and `1e-10 m` for displacement, SSH and each endpoint. Null reference quantities retain absolute errors and undefined relative errors. A true truncation residual is measured evidence and has no smallness gate.

The independent fixture converts the aggregate Legendre pressure to a Chebyshev function using Chebfun, differentiates that function, and evaluates its physical derivatives using the analytic constant/exponential WKB coordinate. It does not call the thermal polynomial worker, decomposition data builder, damping projection or lift. Diagnostic F/G arrays are separately interpolated in the analytic WKB coordinate; a weighted QR F solve and physical endpoint subtraction determine coefficients. Direct physical polarizations and independently contracted self/cross terms supply inventory references. This checks the production stored-coordinate interpolation as well as its numerical contractions. Quadrature refinement holds the stored diagnostic arrays fixed; diagnostic-grid refinement is a separate axis.

Pure APV and separate surface/bottom fixtures first fit known physical pressure into the thermal space. The fit is fixture preparation, not diagnostic accuracy; its pressure, QGPV, endpoint and coefficient effects must be reported separately. Any exploratory fixture failure remains in the execution log and is distinguished from a production failure.

## Reproduction

Use clean `configureCIEnvironment` with the beta.5 snapshot and `maxNumCompThreads(2)`, then run `runtests('UnitTests/TestThermalAPVDiagnostics.m')` and `qualifyThermalAPVDiagnostics(outputDirectory)`. MATLAB R2025b runs outside the local sandbox under the workspace policy. The authoring qualification utility installs its own fixture path; installed public diagnosis requires no fixtures, tools or literature assets.

The small matrix includes constant and exponential controls, Q/2Q/4Q integration, independent stored-grid and APV-band refinements, both signed endpoints, nonzero original MDA, ordered directional tendencies and a narrow-band surface layer. The separate resource/reference pass supplies the one 257-direction target-geometry exponential state. Construction, map preparation, cached metrics and explicit field reconstruction are timed separately. Retained numeric payload and estimated scratch are distinguished from process high-water memory. These measurements describe offline analysis; they do not establish campaign throughput or spatial adequacy.

## Completed small controls

The nine methods in `TestThermalAPVDiagnostics` passed on R2025b. They compare all requested physical volumes with an explicit real Fourier sum, compare APV-first coefficients with `transformStateForward` on matching native grids, retain mean-only and zero states, and check actual ordered nonlinear, seasonal, drag and diffusion process rates at the saved clock. Directional checks include independently differenced self/cross inventories and positive residual-rate norms, including opposite tendencies. The cache test distinguishes one preparation across records from reconstruction for another diagnostic basis, quadrature or restored thermal object; changing the offline band and signed weights preserves the frozen online damping arrays and tendency exactly. A 20-mode diagnostic basis successfully analyzes a 17-direction thermal source; no damping right-inverse rank condition is imposed.

Initial fixture-development errors are retained in [development-findings.csv](development-findings.csv). None led to a scientific tolerance change. The final pure APV/surface/bottom/mixed controls are recorded in [manufactured-fits.csv](manufactured-fits.csv): preliminary source fitting is separated from diagnostic recovery. The largest known-coordinate error is approximately `6e-9`, below `1e-8`; the fitted field itself differs from the desired provider QGPV by less than `8e-12` relative and its endpoints by less than `9e-13 m`. Endpoint subtraction multiplies small displacement differences into coefficient units, so pressure-fit error alone would understate the coordinate effect. Zero-APV QGPV controls retain an absolute source-fit error and an undefined relative fit error.

[SmallReference/residual-reference-budget.csv](SmallReference/residual-reference-budget.csv) reports every required residual observable for constant and exponential mixed controls, including separate surface and bottom rows. Its reference budget includes refinement of both the residual norm and source reference magnitude. Each reported error is divided by the predeclared physical allowance; the independent reference allowance ratio must be at most 0.2 and the diagnostic/source-scale ratios at most 1.

The surface-layer controls make truncation visible. For constant stratification, APV bands of 3, 6 and 10 modes leave QGPV RMS residuals of approximately 89.8%, 79.4% and 66.1%, while the endpoint errors stay below `3e-15 m`. Their physical energy-norm residuals are about 190.6%, 124.1% and 74.9%. An APV-first Galerkin projection is not a minimum-physical-energy fit; an energy-norm residual larger than the source norm is possible. The required self/cross terms still recover the complete source. Endpoint agreement alone does not qualify an interior diagnostic band.


## Numerical results

| Completed evidence | Largest measured error | Gate |
| --- | ---: | ---: |
| Independent coefficient reference, 14 small controls | `2.25e-16` relative | `2e-9` |
| Coefficients versus independent reference | `5.74e-14` relative | `1e-8` |
| Physical self/cross inventories versus independent reference | `1.06e-12` in component majorant | `1e-8` |
| Component recomposition | `3.96e-16` in component majorant | `5e-12` |
| Known APV/endpoint coordinates after separately measured source fit | `5.96e-9` relative | `1e-8` |
| Small-control residual-reference allowance ratio, 18 rows | `2.34e-8` | `0.2` |
| Exact-target residual-reference allowance ratio, nine rows | `1.55e-5` | `0.2` |
| Exact-target diagnostic allowance ratio | `8.32e-4` | `1` |
| Exact-target source-scale allowance ratio | `1.17e-4` | `1` |

Both constant and exponential fixed-band refinements from 129 through 257 to 513 diagnostic depths changed coefficients by at most `3.17e-15` relative. Quadrature refinement holds the stored arrays fixed and measures a separate error. The true residuals below are deliberately not constrained to be small; the diagnostic must report them accurately.

The exact-parameter target's [complete observable ledger](TargetReference/residual-reference-budget.csv) contains these field differences:

| Observable | Absolute residual norm | Residual/source norm |
| --- | ---: | ---: |
| QGPV | `1.70479e-6 s^-1` | `0.78740` |
| Buoyancy | `2.57674e-5 m/s2` | `1.19195` |
| Horizontal velocity | `8.85018e-4 m/s` | `9.75838` |
| Total displacement | `1.74122 m` | `0.86266` |
| Interior displacement | `1.74121 m` | `0.86264` |
| SSH | `6.12419e-5 m` | `0.07162` |
| Surface anomaly | `2.00972e-14 m` | `1.34e-15` |
| Bottom anomaly | `2.03986e-12 m` | `5.13e-12` |
| Positive physical energy norm | `0.250413 m^(3/2)/s` | `1.13556` |

The target pass independently evaluates all physical residuals and source scales and measures resource use. It does not claim a separately measured target coefficient-recovery error, per-target cross-term error, cached median wall time or volume wall time. Those implementation contracts are established by the smaller independent coefficient, physical-field, cross-term and directional controls. All target residual refinements hold its stored 1025-depth diagnostic basis fixed; they do not establish nonlinear campaign spatial accuracy.

## Analysis cost

[TargetReference/resources.csv](TargetReference/resources.csv) records thermal construction at `4.277 s`, diagnostic APV construction at `911.678 s` and the initial numerical-map preparation plus scalar diagnosis at `0.6804 s`. The last quantity includes the first map application; it is not presented as isolated map-build time. The observed APV construction cost supports constructing and saving a reusable diagnostic transform rather than reconstructing it for every analysis session.

The retained data-structure value payload is `59,415,634 bytes` (about 56.7 MiB), including copy-on-write canonical arrays. Requesting all eight physical products returns `159,547,816 bytes` (about 152.2 MiB). The [allocation profile](TargetReference/allocation-profile.csv) records public-method `PeakMem` values of `858,096 bytes` for cached scalar analysis and `10,633,248 bytes` when volumes are requested. These are named-function profiler statistics; they are neither a complete process high-water mark nor a sum of nested allocation rows. The full returned-field payload is reported separately.

Small-control cached medians range from approximately `4.3 ms` to `27.7 ms`, with requested-volume calls around `23 ms` to `157 ms`; the exact-parameter target did not record an unprofiled cached median or volume wall time. Shared-host contention and JIT warm-up affect these observations. T10 retains actual campaign diagnostic-band choice, whole-process memory, whole-model throughput and campaign-resolution decisions.

## Qualification passes and provenance

The small matrix uses `N20=1e-4 s^-2`, latitude 24 degrees, a 100 km square by 1 km depth, 33 thermal directions and native depth count 129. Its 14 numerical cases, eight source fits and 12 refinement rows were saved before the original run was stopped at the optional generic 257-direction construction. That redundant generic target was omitted in favor of the exact-parameter target below; no generic target result is claimed. The saved small-matrix CSVs were independently checked against every declared coefficient, reference, inventory, recomposition and source-fit gate. `fromStratification` defaults to latitude 24 degrees.

The separate `TargetReference` pass uses the seasonal physical parameters explicitly: `N20=(5.2e-3)^2 s^-2`, inverse scale `1/1300 m^-1`, latitude 24 degrees, 500 km square by 4 km, 18 by 18 horizontal points, 257 thermal directions, native count 385, and an independently constructed six-mode APV diagnostic basis on 1025 depths. Both active endpoint weights are signed stratification integrals. The manufactured pressure is a resolved approximation to `100*exp(-30*(1-s))` in the physical WKB coordinate, with a nonzero original thermal mean. It is a bounded instantaneous surface-layer state, not a seasonal trajectory or a campaign-resolution recommendation.

The main matrix and supplemental passes write separate CSV ledgers. The small matrix was already running when per-observable collection was added to the authoring utility; its original [controls.csv](controls.csv), [refinement.csv](refinement.csv) and [manufactured-fits.csv](manufactured-fits.csv) are preserved. The bounded small and exact-parameter target supplements provide the additional observable budgets. Future full-matrix invocations also write those budgets directly.

Reproduce all three passes in fresh output directories after the clean setup shown in [DependencyQualification.md](DependencyQualification.md):

```matlab
qualifyThermalAPVDiagnostics(outputRoot,shouldRunTarget=false);
qualifyThermalAPVDiagnostics(fullfile(outputRoot,"SmallReference"),residualControlsOnly=true);
qualifyThermalAPVDiagnostics(fullfile(outputRoot,"TargetReference"),resourcesOnly=true);
```

The target allocation pass uses MATLAB's `profile on -memory` after map preparation. It records the public method, core worker and helper allocation rows separately for cached scalar analysis and requested physical volumes. `PeakMem` is the MATLAB profiler's allocation measure for the named function. Nested rows are not summed, and none is identified as whole-process RSS. The utility replaces recorded profile data intentionally while restoring the profiler configuration, including detail and memory tracking, through cleanup. `whos` on a separately built numerical-data structure reports retained value payload, including canonical arrays shared through copy-on-write; it does not measure exclusive cache ownership. Timings are observed on a shared Apple Silicon host with concurrent user work and two computation threads per qualification process. They establish cost categories and reuse, not isolated throughput or whole-model performance.

The provider revision and exact package graph are in [DependencyQualification.md](DependencyQualification.md). Saved-output, committed-tail, nested-stream and provider-unavailable results are in [OutputQualification.md](OutputQualification.md). Integration, installation, documentation and final CI evidence belong to [VerificationLedger.md](VerificationLedger.md); scientific interpretation and T10 boundaries are in [ImplementationHandoff.md](ImplementationHandoff.md).

## Verification record

- Final scientific unit class: nine methods passed; added fixture/class files initially reported zero Code Analyzer messages. The subsequently strengthened residual-rate method passed independently after the core rate-energy correction.
- The complete small matrix finished and saved 14 numerical rows, eight source-fit rows and 12 refinement rows. The optional duplicate generic target was stopped after those writes. A separate CSV audit checked every numerical gate and all expected row counts.
- The bounded small residual pass returned successfully with 18 observable rows. Its reference-error ratio includes both residual and reference-magnitude refinement.
- The exact-parameter target returned successfully with nine observable rows and its allocation/resource tables. This earlier loaded resource body records refinement of the residual norm and the actual source-scale discrepancy against the fine independent reference; the final utility additionally includes source-scale refinement in its reference budget. No unrecorded target source-scale-refinement estimate is claimed here.
- The final utility restores the complete profiler configuration, including memory tracking and detail. The restoration mechanism was exercised separately on R2025b because `profile('status')` does not expose memory configuration.
- No full seasonal trajectory, nonlinear campaign or whole-model performance study was rerun. No historical input files were required, and no numerical check in the completed T9 scope remains blocked.
