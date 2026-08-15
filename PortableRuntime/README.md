# WaveVortex portable runtime

`WaveVortexPortableRuntime` contains the MATLAB-independent constant-stratification runtime layers built around the shared C++ numerical kernel. It reads and writes compatible WaveVortexModel 4.x checkpoints, resolves supported frozen forcing records at construction, evaluates the combined right-hand side, and advances canonical `[Nj,Nkl]` coefficients with fixed-step RK4 or adaptive Bogacki--Shampine RK3(2).

The library deliberately does not reproduce the general MATLAB `NetCDFFile` or `CAAnnotatedClass` APIs. Its private NetCDF-C layer supports only the group, attribute, dimension, variable, hyperslab, and complex-pair reads required by compatible WaveVortex checkpoints.

The data-only `wave-vortex-forcing-v1` contract preserves MATLAB forcing class names, resolved stages, priorities, stable source order, and immutable source parameters. It does not reproduce MATLAB handle objects. Derived damping operators, topographic response arrays, FFT plans, and workspaces are rebuilt at runtime and are never checkpoint state.

Runtime v1 recognizes six forcing records:

- `WVNonlinearAdvection`
- `WVAdaptiveDamping`
- `WVFixedAmplitudeForcing`
- `WVBottomFrictionQuadratic`
- `WVPseudoTopographicWaveGeneration`
- `WVBetaPlanePVAdvection`

Transform-level antialiasing is carried by `shouldAntialias`. Explicit `WVAntialiasing`, the other supplied forcing classes, and arbitrary subclasses are reported as unsupported before runtime construction.

The numerical target `WaveVortexKernel` has no NetCDF dependency. The portable runtime composes the boundaries without moving NetCDF into the core:

```text
compatible WaveVortex NetCDF file
            |
   WaveVortexPortableRuntime  -- NetCDF C at the checkpoint boundary
            |
      WaveVortexKernel    -- no NetCDF or MATLAB APIs
```

The forcing engine executes records in frozen stage, priority, and source order. It implements nonlinear advection, adaptive damping, fixed amplitude, quadratic bottom friction, pseudo-topographic wave generation, and beta-plane QGPV advection. Fixed-amplitude coefficients are restored after restart, before each Runge--Kutta stage, and after each completed step.

`WVIntegrationStateLayout` gives every numerical method the same state contract: canonical `Ap`, `Am`, and `A0` plus zero or more typed observer-owned blocks. A coefficient-only run is the zero-additional-block case, not a separate integrator implementation. `WVIntegrationSystem` owns right-hand-side evaluation, constraints, and a method-neutral error policy; `WVTimeIntegrator` owns accepted-step advancement; and `WVDenseOutput` owns continuous extension. A new integrator or observer state block can therefore use the existing output driver without adding method or observer branches to orchestration.

Classical RK4 normally uses one stage state, one stage tendency, and one weighted accumulator for every integrated component. Coefficient-only exact workspace is `9*M*sizeof(WVComplex64)`, where `M=Nj*Nkl`. With `WVFixedStepRK4Options{true}`, one additional history state supports the cubic Hermite extension exposed through `WVAcceptedStep`, for `12*M*sizeof(WVComplex64)`. `advanceToTime` uses the requested fixed step and one deterministic shorter final step when needed. FFT plans, derived forcing operators, method workspace, and dense-output history are rebuilt rather than persisted.

`WVAdaptiveRK23` uses the four-stage Bogacki--Shampine 3(2) pair, a cubic stage-derived extension, and FSAL endpoint-derivative reuse when state constraints permit it. Rejected attempts leave every accepted state block unchanged and emit no output. Its atomic candidate plus four derivative states retain `15*M*sizeof(WVComplex64)` in a coefficient-only run. The controller does not construct WaveVortex tolerances or inspect forcing; `WVIntegrationSystem` supplies absolute tolerances for all canonical and additional state components.

`WVOutputPlan` is independent of the integration method. Regular plans resolve all configured files, named groups, observer references, and bounded schedule occurrences. Explicit plans carry arbitrary requested times and destinations for the command-line checkpoint workflow. Schedule ordinals remain anchored to each group's original `initialTime + ordinal*outputInterval` lattice, and caller-supplied `WVOutputGroupProgress` excludes committed ordinals during segmented continuation. Only exactly equal occurrence times are aggregated; distinct ordinals from one group remain distinct events. Events are delivered in file, group, then observer order while shared observers retain one resolved identity.

`WVOutputDriver` requires exact structural equality between the plan and integrator state layouts, preallocates one reusable event state, and calls an abstract sink's guarded, non-writing `preflight` boundary before integration. Accepted steps never consult output times, and interpolated state never becomes accepted state. A failed route leaves its exact event state and route cursor staged, so a later call retries only that uncommitted route before continuing from the latest accepted endpoint. Sink callbacks are non-reentrant. Metrics report exact schedule/event, attempt, commit, write, failure, interpolation, and retained-capacity counts.

`WVConstantStratificationIntegrationSystem` integrates MATLAB-compatible `WVLagrangianParticles` and three-dimensional `WVTracer` state beside the canonical coefficients. Every RHS evaluation asks the forcing engine for one generation-checked context containing the `u`, `v`, and `w` fields already reconstructed by `nonlinearFlux`; particles and tracers consume that same immutable view. If a forcing schedule does not reconstruct velocity, the context prepares it once on demand. Particle records resolve ordered x/y/optional-z blocks at construction. XY-only particles retain configured z values without integrating them, and accepted horizontal coordinates remain unwrapped because periodic reduction belongs solely to interpolation. A tracer retains its natural `[Nx,Ny,Nz]` state and evaluates `-u*d_x C-v*d_y C-w*d_z C` through the kernel's shared F-grid differential operators. Its `shouldAntialias` setting controls the post-product horizontal projection. Two-dimensional tracer state remains persistable but is rejected by this baroclinic runtime pending a barotropic numerical implementation. Fixed RK4, adaptive RK3(2), rejected-step semantics, and dense output operate on every integrated block without observer-specific logic in the numerical methods.

`WVModelOutputNetCDFSink` implements that sink contract with the existing MATLAB 4.x output-file semantics. It stages every new destination before committing the file set and stores one unlimited `t` dimension per named output group. Nonlinear coefficient restarts use real/imaginary `[t,kl,j]` pairs; linear files retain MATLAB's initial-only `[kl,j]` coefficient convention while their output time axis and other time-series fields continue to grow. Payload variables are written before `t`; after `t` is committed the file is synchronized. Inspection and append reject fill-valued partial records, cadence or shape changes, off-lattice or duplicate times, unsupported observer tags, broken shared identities, and files without exactly one complete coefficient restart group. `inspect()` reconstructs the portable descriptor, schedule progress, latest canonical state, and required dynamic observer state from MATLAB- or runtime-produced files. Plans, caches, dense-output history, controller state, and scratch are never persisted.

The exported source package builds the optimized Apple-silicon runner through:

```sh
PortableRuntime/buildWaveVortexRun.sh
```

The script verifies the pinned FFTW archive before compiling it into an ignored local cache. WaveVortexModel distributes neither that archive nor FFTW libraries, MEX files, or executables. A locally linked executable includes GPL-licensed FFTW, so redistribution of that executable must satisfy FFTW's GPL terms.

The authoring contract suite builds this target and its standalone inspector through:

```sh
tools/compiled-kernel/run_contract_tests.sh
tools/compiled-kernel/build-portable/wv_checkpoint_inspect checkpoint.nc
tools/compiled-kernel/build-portable/wv_checkpoint_roundtrip input.nc output.nc
tools/compiled-kernel/build-portable/wv_checkpoint_inspect --forcing-capabilities
tools/compiled-kernel/build-portable/wv_portable_forcing_inspect checkpoint.nc
tools/compiled-kernel/build-portable/wv_portable_rk4_inspect checkpoint.nc finalTime deltaT
tools/portable-runtime/runFieldEvaluationContracts.sh
tools/compiled-kernel/build-portable/wv_field_evaluation_inspect checkpoint.nc
```

`WVCheckpointWriter` emits a root-level scalar checkpoint using the existing `[kl,j]` real/imaginary encoding and annotated forcing groups. It validates and re-reads a same-directory temporary file before atomically replacing the destination. A failed validation, write, close, or commit leaves an existing destination unchanged. The writer persists the canonical state and immutable forcing source data only; `deltaT`, plans, derived forcing operators, mappings, caches, and scratch remain runtime-derived.

The v1 writer intentionally does not append records or produce a time-series group. The reader continues accepting both scalar root checkpoints and existing nested time-series files.

## Field evaluation

`WVFieldEvaluationService` is the backend-neutral diagnostic boundary for constant-stratification fields. Construction owns the transform, FFT plans, mappings, and bounded reusable scratch. An immutable `WVFieldEvaluationPlan` resolves field dependencies and interpolation weights once; evaluation accepts a transient coefficient-state view and writes every requested value into caller-owned output buffers. Coefficient streams and static model metadata remain outside this service.

Plans can request full native grids, fixed vertical profiles using MATLAB one-based horizontal indices, or arbitrary positions using periodic-horizontal `linear` or `spline` interpolation. `WVMovingFieldEvaluationPlan` adds transient coordinates without rebuilding a plan or retaining per-particle spline weights. One reusable x/y/z spline workspace serves all particles and requested fields. Moving plans currently support the primitive volumetric fields `u`, `v`, `w`, `eta`, `rho_e`, and `rho_total`; unsupported tracked fields are rejected before integration. Coincident requests share primitive transforms and field sources. The full fixed-position catalog remains `u`, `v`, `w`, `eta`, `pi`, `p`, `psi`, `qgpv`, `rho_e`, `rho_total`, `rho_bar`, `zeta_x`, `zeta_y`, `zeta_z`, `ssu`, `ssv`, `ssh`, `energy`, `uvMax`, and `wMax`.

The service metrics report plan, transform, service, and scratch storage; transform and FFT execution counts; coincident batches and source reuse; sampling operations; and exact caller-output element writes. Scratch high-water storage never exceeds the fixed service capacity, and repeated evaluations do not retain coefficient states or sampled results.

`WVObserverOutputEvaluationService` adds observer semantics above field evaluation. It exposes `WVCoefficients`, `WVEulerianFields`, `WVMooring`, and `WVLagrangianParticles` using MATLAB class names, variable names, logical dimensions, units, descriptions, and cadence. Coefficients are borrowed directly from immutable event state. Particle coordinates are read from accepted or dense-output integration state, while XY-only z remains fixed configuration. Coincident routed particles share one transform, and events without a particle route do not evaluate particle fields. Call `useFieldEvaluationService` with the integration system's evaluator to reuse its transform and FFT plans. Particle IDs are one-based; x, y, z, and tracked values use `[id,t]` logical order and MATLAB's particle metadata attributes.

The closed version-1 built-in set is registered through the internal `WVObserverAdapter` seam. That table owns portable tags, MATLAB class names, state contracts, metadata conventions, and output rules; persistence and evaluation do not maintain separate tag maps. Particle and tracer state channels are named internally, but no enum value is serialized. Adding a built-in remains a source-level runtime change with compatibility tests, not a third-party plug-in ABI.

## Standalone executable

The default CMake build produces `wave-vortex-run` with the scalar reference FFT engine for portable correctness testing. The optimized Apple-silicon executable is source-only and uses the shared pinned-provider manifest:

```sh
PortableRuntime/buildWaveVortexRun.sh
```

The executable requires an explicit provider and exactly one endpoint:

```sh
wave-vortex-run input.nc output.nc --delta-t 1 --steps 8 --fft-provider native-fftw --threads 18 --report run.json
wave-vortex-run input.nc output.nc --delta-t 1 --final-time 100 --fft-provider native-fftw
wave-vortex-run input.nc output.nc --integrator adaptive-rk23 --delta-t 1 --final-time 100 --relative-tolerance 1e-3 --absolute-tolerance 1e-6 --fft-provider native-fftw
```

Exit codes distinguish usage (`2`), checkpoint/preflight (`3`), provider (`4`), integration (`5`), and output (`6`) failures. The JSON report records each execution phase separately. The private `--phase-file` option exists only for the authoring RSS benchmark and is not part of the supported command-line contract.
