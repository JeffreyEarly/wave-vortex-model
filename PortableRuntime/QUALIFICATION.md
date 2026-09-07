# Stratified QG qualification

`WVTransformStratifiedQG` supports complete MATLAB-authored portable model continuation with A0-only state, the nine applicable stable forcings, Eulerian and surface fields, three-dimensional fixed/moving/event sampling, fixed-depth XY drifters, rank-three XY tracers, moorings and linear passive observers. Model graphs retain multi-file/group identities, schedules, dense output, create/replace/append and restart. MATLAB reopens the output directly. See [README.md](README.md#stratified-qg-model-integration) for the execution surface and scientific persistence contract.

A three-dimensional SQG tracer must use `WVTracer(...,isXYOnly=true)`. This describes its horizontal advection on `[Nx,Ny,Nz]`; it does not flatten the tracer. MATLAB SQG has no `w`, so vertical tracer advection is an intentional preflight incompatibility. Hydrostatic and other unimplemented transform model graphs remain outside this SQG qualification. Existing MATLAB constructors, readers, required properties and save behavior remain unchanged.

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

The shared forcing catalog contains 96 rows, including SQG's 17 supported and 7 intentionally incompatible rows across both transform-antialias configurations. Existing exact-pair tests compare every applicable RHS and append continuation, with odd/even grids and representative closure orderings. Their MATLAB-authoritative applicability and evidence links remain in the same catalog used by C++ contracts.

`contracts/stratified-qg-qualification-cases-v1.json` declares six longer complete-model cases. They span odd/even grids, one through six retained modes, explicit and transform antialiasing, fixed amplitudes, nonlinear closure compositions, linear passive observers, RK4/RK23/RK78, explicit steps, CFL-selected RK4 and default adaptive initial steps. Each run covers 600 seconds with primary output every 100 seconds and dense output every 25 seconds; its uninterrupted and two-segment trajectories are compared against MATLAB. Nonlinear cases must change A0 by at least `1e-4` in relative maximum norm, preventing nearly stationary trajectories from passing as substantive qualification.

Comparisons include coefficients, fields, energy, enstrophy, tracer state, particle positions and tracked fields, mooring records, dense fields, observer ordering, schedule times and committed ordinals. Explicit/fine-CFL trajectories use a `2e-7` relative maximum-error ceiling, while default adaptive segmented trajectories use `5e-4`, below MATLAB's default `1e-3` relative tolerance. Particle positions have a `0.02 m` ceiling. Reports retain the measured errors, not merely Boolean outcomes. Existing finer exact-pair tests continue to impose their tighter operation-level tolerances.

Fixed RK4 has an explicit endpoint distinction: C++ shortens the final step to land on the requested time; MATLAB's `WVArrayIntegrator` takes a full step and interpolates back. Segment boundaries can therefore change the discrete trajectory. The CFL case checks that reducing the step by ten decreases the endpoint coefficient difference by at least one hundred, in addition to meeting the fine-step parity ceiling. This qualification preserves both established behaviors and does not claim bitwise endpoint equality when the step grids differ.

## Runtime and storage

The lifecycle probe constructs, advances and destroys six complete models at each of three grid sizes. It checks that the scientific modal owner expires, prepared retained capacities remain constant over sixteen measured RK4 steps after warmup, and native prepared steps make zero application C++ allocations. A qualification-discovered fix reuses RK4's existing coefficient/block view vectors instead of allocating two metadata vectors per step; no state-sized buffer or numerical formula changed.

Runtime reports retain RHS counts, field reconstruction/projection counts, timing, integrator storage-ledger agreement and RSS diagnostics. SQG closures and distinct event occurrences currently reconstruct independently. Further reuse or backend tuning should follow measurements of the same workload. Retained-capacity accounting excludes allocator metadata and opaque NetCDF/FFTW internals; RSS is a process measurement rather than proof of exact live array storage. Timing is descriptive, with no machine-dependent CI speed threshold.

The authoring repository retains the [issue-298 verification ledger](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/.github/planning/issue-298-verification.md). Issue #306 consumes this qualification alongside the same expanded forcing slice when assembling the full feature catalog.
