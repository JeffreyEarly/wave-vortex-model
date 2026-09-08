# Portable transform qualification

## Hydrostatic qualification

`WVTransformHydrostatic` supports MATLAB-authored model continuation with Ap/Am/A0 state, variable stratification, all twelve stable forcing identities where MATLAB permits them, full or horizontal-only tracers and particles, moorings, surface and volume fields, dense output, multiple output files, append and restart. MATLAB reopens the resulting model graphs directly. The scientific modal source and opaque `N2Function` payload are preserved. No MATLAB execution or eigensolver is needed during C++ continuation; MATLAB constructors, scientific methods and save defaults are unchanged.

After `tools/configureCIEnvironment`, run:

```matlab
qualifyPortableHydrostatic("hydrostatic-reference.json");
qualifyPortableHydrostatic("hydrostatic-native.json",runner="/path/to/build/wave-vortex-run",native=true);
```

The supplied runner needs matching `WVStableForcingDump`, `WVStratifiedQGFieldDump` (the shared stratified field probe), `WVHydrostaticLifecycleProbe`, `WVStratifiedQGLifecycleProbe`, `WVStratifiedModalDump` and `WVHydrostaticKernelDump` executables beside it. Without a supplied runner the tool builds the reference configuration. Native qualification includes the reference provider and native FFTW, plus scalar/Accelerate matrix parity in the numerical kernel tests. Complete model runs currently use the scalar matrix backend; this evidence does not claim Accelerate selection through the runner.

The `wave-vortex-hydrostatic-qualification-v1` report links executed tests to the existing forcing catalog, including all 23 supported Hydrostatic forcing/antialias pairs and the intentional antialias-on-antialias incompatibility. It records the source revision, working-tree status, MATLAB release, provider, timing, storage and measured continuation errors. `validatePortableHydrostaticQualification` rejects missing, duplicate, stale, contradictory or out-of-tolerance evidence. The focused Hydrostatic workflow runs reference release and ASan/UBSan qualification and uploads separate reports, independently of optional Full CI.

### Numerical coverage

`contracts/hydrostatic-qualification-cases-v1.json` declares six 600-second trajectories using exponential and thermocline stratification, nonuniform vertical grids, odd/even horizontal grids, modal truncation, transform and explicit antialiasing, linear/nonlinear dynamics, and full/XY observer advection. RK4, RK3(2) and RK7(8) cover explicit, CFL-selected and default adaptive stepping. Each uninterrupted trajectory and two-segment append/restart trajectory is compared against MATLAB. Primary output is every 100 seconds and dense output every 25 seconds, including the initial state.

The coefficient comparison bounds each of Ap, Am and A0 separately. Further comparisons cover fields, energy, enstrophy, tracers, all three particle coordinates, tracked fields, moorings, dense fields, forcing identities, observer ordering, output variable schemas, schedules and ordinals. Explicit/CFL cases use a `2e-7` relative maximum-error ceiling; default adaptive cases use `5e-4`, below MATLAB's default `1e-3` relative tolerance. Particle positions have a `0.02 m` ceiling. Nonlinear cases must change the coefficient state by at least `1e-4` in relative maximum norm. The existing focused Hydrostatic tests additionally exercise non-prefix modal subsets, malformed metadata, exact forcing tendencies and continuations, and transactional multi-file create/replace/append behavior.

The CFL fixture requests the CFL number that selects a five-second step at each segment's initial state. This keeps MATLAB and C++ on a shared step grid while checking Hydrostatic advective/oscillatory step selection. It does not change the existing endpoint policies: C++ shortens a final step, while MATLAB can take a full step and interpolate. Fixtures avoid the existing MATLAB adaptive-damping degeneracy when explicit antialiasing leaves only one positive vertical mode.

### Runtime, memory and lifecycle scope

The shared stratified lifecycle probe constructs, warms up, advances and destroys six complete models per case. Both providers run 8×6×9, 12×10×13 and 20×16×17 grids; native FFTW additionally runs 64×48×49 with 24 modes. Large cases are native-only because the reference implementation uses a direct DFT. Reference-only runs use the 8×6×9 and 12×10×13 lifecycle fixtures and rely on the dedicated SQG workflow for its lifecycle regression. The declared `referenceOnlyLifecycleGrids` bounds the unoptimized direct-DFT workload on hosted runners; all six continuation fixtures and kernel/forcing parity cases remain required. Native-plus-reference runs retain all seven lifecycle/provider cases described above. Each lifecycle records setup time, sixteen measured RK4 steps, 64 RHS evaluations, reconstruction/projection counts and retained capacities. It verifies modal-source ownership release after destruction, unchanged prepared capacities and zero native C++ application allocations. These prepared-step measurements occur between output events; the continuation reports separately include real output/restart work.

Retained bytes count integration-system, integrator, state and output capacities. Scientific bytes are also reported for inspection. Allocator metadata and opaque FFTW/NetCDF internals are outside this accounting; process RSS in the runtime report is diagnostic, not an exact live-array ledger. Timing is descriptive, with no machine-dependent CI speed threshold.

The recorded [Apple Silicon Hydrostatic report](qualification/hydrostatic-apple-silicon-v1.json) contains 41 passing tests, 47 forcing/provider results, twelve continuation results and seven lifecycle results. The maximum coefficient-family discrepancy is `5.19e-9`; the maximum particle-position discrepancy is `2.62e-6 m`. All lifecycle cases report zero retained growth and zero prepared allocations. Representative native measurements are:

| Grid / modes | Retained capacities | Median time for 16 RK4 steps |
| --- | ---: | ---: |
| 8×6×9 / 4 | 372,498 bytes | 0.00271 s |
| 12×10×13 / 6 | 856,354 bytes | 0.0116 s |
| 20×16×17 / 8 | 2,543,002 bytes | 0.0486 s |
| 64×48×49 / 24 | 66,545,802 bytes | 2.91 s |

These samples ran on a shared development host; they establish descriptive baselines rather than isolated speed comparisons. The forcing-service counters record 128 physical-bundle reconstructions and 192 spatial projections per 64 RHS evaluations. They do not include every field reconstruction performed by the separate sampling/output services.

Hydrostatic spatial closures still project separately, and integrated observers may reconstruct fields after the forcing RHS. The qualification records this schedule before optimization. Backend selection and safe per-RHS field reuse remain possible measured follow-ups. Variable-stratification Boussinesq wave matrices, their horizontal-wavenumber groups and full Boussinesq runtime qualification remain the next transform gap.

## Stratified QG qualification

`WVTransformStratifiedQG` supports complete MATLAB-authored portable model continuation with A0-only state, the nine applicable stable forcings, Eulerian and surface fields, three-dimensional fixed/moving/event sampling, fixed-depth XY drifters, rank-three XY tracers, moorings and linear passive observers. Model graphs retain multi-file/group identities, schedules, dense output, create/replace/append and restart. MATLAB reopens the output directly. See [README.md](README.md#stratified-qg-model-integration) for the execution surface and scientific persistence contract.

A three-dimensional SQG tracer must use `WVTracer(...,isXYOnly=true)`. This describes its horizontal advection on `[Nx,Ny,Nz]`; it does not flatten the tracer. MATLAB SQG has no `w`, so vertical tracer advection is an intentional preflight incompatibility. Hydrostatic models have their own qualification above. Existing MATLAB constructors, readers, required properties and save behavior remain unchanged.

## Run and inspect the evidence

From the authoring repository, configure the MATLAB dependencies with `tools/configureCIEnvironment`, then run:

```matlab
addpath("tools");
qualifyPortableStratifiedQG("sqg-reference.json");
```

The tool builds a temporary reference runner and probes, executes the qualification and existing regressions, writes JSON evidence, then validates it. A failed or incomplete run writes `status="incomplete"` and raises an error. Native qualification requires an explicitly built native runner and matching probes beside it:

```matlab
qualifyPortableStratifiedQG("sqg-native.json",runner="/path/to/build/wave-vortex-run",native=true);
```

Build targets are `wave-vortex-run`, `WVStableForcingDump`, `WVStratifiedQGFieldDump`, `WVStratifiedQGLifecycleProbe` and `WVStratifiedModalDump`. The native run executes both reference and native FFTW providers. No fallback is permitted. The authoring tool and tests are not required to execute an exported model bundle.

The JSON uses `wave-vortex-sqg-qualification-v1`. It records source revision and dirty status, MATLAB release/platform, the exact digest of the existing forcing catalog, executed test outcomes, catalog-row/provider results, continuation errors, selected stepping controls, runtime work, reported storage and repeated lifecycle measurements. Intentional forcing incompatibilities are provider-independent preflight results; they are recorded once under the reference run. `validatePortableStratifiedQGQualification` rejects missing, duplicate, stale-catalog, contradictory, failed or out-of-tolerance evidence. The evidence is a result of executing the existing compatibility slice, not another independently maintained support matrix.

The dedicated `Stratified QG qualification` workflow runs reference-provider release and ASan/UBSan qualification on Linux and uploads separate JSON artifacts. It runs independently of the optional Full suite. Native FFTW qualification is performed on the supported local Apple Silicon build; the report identifies the actual provider/library. An artifact demonstrates its recorded configuration, rather than certifying every compiler/platform or an exhaustive cross-product.

The recorded [Apple Silicon reference/native qualification](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/PortableRuntime/qualification/stratified-qg-apple-silicon-v1.json) contains 34 passing tests, 41 forcing/provider results, 12 continuation cases and six lifecycle results. Its source revision is recorded before the artifact itself is added to the repository.

## Numerical coverage and tolerances

The shared forcing catalog contains 120 rows, including SQG's 17 supported and 7 intentionally incompatible rows across both transform-antialias configurations. Existing exact-pair tests compare every applicable RHS and append continuation, with odd/even grids and representative closure orderings. Their MATLAB-authoritative applicability and evidence links remain in the same catalog used by C++ contracts.

`contracts/stratified-qg-qualification-cases-v1.json` declares six longer complete-model cases. They span odd/even grids, one through six retained modes, explicit and transform antialiasing, fixed amplitudes, nonlinear closure compositions, linear passive observers, RK4/RK23/RK78, explicit steps, CFL-selected RK4 and default adaptive initial steps. Each run covers 600 seconds with primary output every 100 seconds and dense output every 25 seconds; its uninterrupted and two-segment trajectories are compared against MATLAB. Nonlinear cases must change A0 by at least `1e-4` in relative maximum norm, preventing nearly stationary trajectories from passing as substantive qualification.

Comparisons include coefficients, fields, energy, enstrophy, tracer state, particle positions and tracked fields, mooring records, dense fields, observer ordering, schedule times and committed ordinals. Explicit/fine-CFL trajectories use a `2e-7` relative maximum-error ceiling, while default adaptive segmented trajectories use `5e-4`, below MATLAB's default `1e-3` relative tolerance. Particle positions have a `0.02 m` ceiling. Reports retain the measured errors, not merely Boolean outcomes. Existing finer exact-pair tests continue to impose their tighter operation-level tolerances.

Fixed RK4 has an explicit endpoint distinction: C++ shortens the final step to land on the requested time; MATLAB's `WVArrayIntegrator` takes a full step and interpolates back. Segment boundaries can therefore change the discrete trajectory. The CFL case checks that reducing the step by ten decreases the endpoint coefficient difference by at least one hundred, in addition to meeting the fine-step parity ceiling. This qualification preserves both established behaviors and does not claim bitwise endpoint equality when the step grids differ.

## Runtime and storage

The lifecycle probe constructs, advances and destroys six complete models at each of three grid sizes. It checks that the scientific modal owner expires, prepared retained capacities remain constant over sixteen measured RK4 steps after warmup, and native prepared steps make zero application C++ allocations. A qualification-discovered fix reuses RK4's existing coefficient/block view vectors instead of allocating two metadata vectors per step; no state-sized buffer or numerical formula changed.

Runtime reports retain RHS counts, field reconstruction/projection counts, timing, integrator storage-ledger agreement and RSS diagnostics. SQG closures and distinct event occurrences currently reconstruct independently. Further reuse or backend tuning should follow measurements of the same workload. Retained-capacity accounting excludes allocator metadata and opaque NetCDF/FFTW internals; RSS is a process measurement rather than proof of exact live array storage. Timing is descriptive, with no machine-dependent CI speed threshold.

The authoring repository retains the [issue-298 verification ledger](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/.github/planning/issue-298-verification.md). Issue #306 consumes this qualification alongside the same expanded forcing slice when assembling the full feature catalog.
