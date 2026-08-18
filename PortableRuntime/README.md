# WaveVortex portable runtime

This directory contains the optional, MATLAB-independent constant-stratification runtime. MATLAB remains WaveVortexModel's primary interface. The portable runtime is a source-only checkpoint-to-checkpoint tool for advanced users and a C++ extension surface for future numerical methods and observing systems.

The runtime supports:

- fixed-step RK4 and adaptive Bogacki--Shampine RK3(2), including continuous output derived from each method's Runge--Kutta stages;
- the frozen v1 forcing subset (`WVNonlinearAdvection`, `WVAdaptiveDamping`, `WVFixedAmplitudeForcing`, `WVBottomFrictionQuadratic`, `WVPseudoTopographicWaveGeneration`, and `WVBetaPlanePVAdvection`);
- the five qualified built-in observer records (`WVCoefficients`, `WVEulerianFields`, `WVMooring`, `WVLagrangianParticles`, and `WVTracer`);
- MATLAB-compatible checkpoint and time-series NetCDF data for the documented constant-stratification subset.

Arbitrary MATLAB forcing or observing-system subclasses are not supported. Multi-file, named-group observing-system output is authored in MATLAB and executed by the command-line program without reproducing that scientific configuration in a second format.

`WVModel` is the thin, move-only runtime façade. It owns the resolved forcing, observers, numerical system, integrator, output evaluation, driver, and sink; `WVModelState` separately owns canonical coefficients and dynamic observer state. The same façade backs the standalone runner and the production MEX right-hand-side path. It adds no numerical algorithm or state-sized copy.

Library clients may configure output with the provisional C++ `WVModelOutputFile` and `WVModelOutputGroup` builders. Their MATLAB-shaped methods compile once into the existing immutable descriptor, output plan, driver, and NetCDF sink. Builders are consumed before integration and add no runtime graph or state-sized storage. One create, replace, or append policy applies to the complete file set. `WVModel::createFromModelOutputFiles` instead consumes a complete MATLAB-authored sibling NetCDF set and may remap destinations by stable file identifier without changing observers, groups, or schedules.

## Build

A portable reference build requires CMake 3.20, a C++17 compiler, and NetCDF C:

```sh
cmake -S PortableRuntime -B build/portable -DCMAKE_BUILD_TYPE=Release
cmake --build build/portable --parallel
ctest --test-dir build/portable --output-on-failure
```

On Apple silicon, the optimized runner can be built with:

```sh
PortableRuntime/buildWaveVortexRun.sh
```

The script verifies the pinned FFTW 3.3.11 archive, builds it in the ignored `.compiled-backend-cache`, and links the runner locally. WaveVortexModel distributes no FFTW archive, library, MEX file, or executable. Redistributing a locally linked executable requires compliance with FFTW's GPL license.

## MATLAB-authored run bundles

A portable run has two parts:

- one or more NetCDF files authored by MATLAB, which remain authoritative for model configuration, state, forcing, observers, output groups, schedules, and restart progress;
- a small JSON request, which selects integration, execution, destination paths, and the report location.

Copy [`examples/portable-run-request-v1.json`](examples/portable-run-request-v1.json), list the complete sibling NetCDF set, and map every stable output-file identifier when using `create` or `replace`. Paths are resolved relative to the request file.

```sh
wave-vortex-run --request portable-run-request-v1.json
```

The runner first parses the strict versioned schema, inspects the complete NetCDF graph, resolves every paired forcing and observer, validates the integrator and complete destination policy, and compiles the sole output graph. Only then does it construct the FFT provider and state-sized runtime storage. The JSON cannot add observers, forcings, groups, or schedules. A future MATLAB helper will write this small request automatically; until then it is deliberately straightforward to author alongside the NetCDF bundle.

`create` and `replace` require a complete destination map and never mutate source files. `append` may use the source destinations with an empty map or a complete remap to an existing compatible file set. A partial remap, source alias, incompatible graph, or unsupported paired implementation fails before output mutation.

## Legacy run and restart

The optimized command-line program requires an explicit FFT provider. Complete-model continuation restores and appends the selected file's supported observing-system graph and schedules:

```sh
wave-vortex-run saved-model.nc \
    --restart-mode model \
    --output-policy append \
    --delta-t 1 --final-time 100 \
    --fft-provider native-fftw --threads 18

wave-vortex-run saved-model.nc \
    --restart-mode model \
    --output-policy append \
    --integrator adaptive-rk23 \
    --delta-t 1 --initial-step 1 --maximum-step 10 --final-time 100 \
    --relative-tolerance 1e-3 --absolute-tolerance 1e-6 \
    --fft-provider native-fftw
```

For adaptive integration, `--delta-t` remains the backward-compatible initial-step default. `--initial-step` overrides it explicitly. `--maximum-step` defaults to one tenth of the requested continuation interval, matching MATLAB `ode23`; name it explicitly when comparing runs or continuing the same controller policy across segments. The run report records the controller, effective limits, tolerance hash, accepted and rejected work, and bounded accepted-step diagnostics.

Use `--restart-mode coefficients --output-policy create` with positional input and output paths for an explicit reduced checkpoint-only workflow. `create` refuses existing files; `replace` must be named to authorize atomic replacement. The legacy complete-model form accepts only `append` and validates compatibility before mutation. It remains available for scripts that operate on a single output file; `--request` is the preferred complete multi-file boundary and cannot be mixed with legacy semantic flags.

Plans, caches, integrator history, derived forcing operators, and scratch are rebuilt after restart rather than persisted.

## Architecture

`WVIntegrationStateLayout` describes canonical `Ap`, `Am`, and `A0` plus any observer-owned state blocks. `WVIntegrationSystem` supplies the right-hand side and constraints, `WVTimeIntegrator` advances accepted state, and `WVDenseOutput` evaluates within an accepted step. Output orchestration depends only on those contracts, so another integrator or state block does not require changes to the driver.

`WVModel` composes these services but does not replace them. High-level restart, RHS, step, integration, output progress, and metrics operations delegate to the same contracts used before the façade. Model-output construction inspects all sibling files together, restores the latest complete compatible state, and compiles the recovered graph directly into the existing plan and sink.

`WVObservingSystem` is the provisional, source-linked C++ implementation boundary for a paired MATLAB observer. `WVObserverFactoryRegistry` resolves an exact MATLAB type identifier and contract version to one immutable implementation before integration storage is allocated, and `WVPortableObserverDescriptor` retains that resolution. The five built-ins use the same path. Implementations validate their configuration and declare coarse state, dependency, right-hand-side, sampling, and persistence behavior; the integration and output services invoke them no more finely than once per observer, stage, or output event. Element loops remain in the specialized particle, tracer, and field-evaluation kernels.

The registry deliberately has process lifetime: the first descriptor seals it, so duplicate, conflicting, or late registrations fail deterministically. Runtime routes carry resolved implementation pointers and variable ordinals rather than class names. `WVFieldEvaluationService` shares primitive field reconstruction across observers, and `WVModelOutputNetCDFSink` remains the sole owner of transactional MATLAB-compatible persistence. Observer implementations supply data-only schema and sample descriptions and never call NetCDF. The numerical kernel has no MATLAB, MEX, NetCDF, or Apple API dependency.

Registrations include the exact paired MATLAB/C++ identity and contract version and must be installed before the first observer descriptor is constructed. Descriptor construction seals the registry; integration performs no registration discovery or class-name lookup.

`WVForcingFactoryRegistry` provides the corresponding source-level seam for forcing pairs. It maps exact MATLAB identities and versions to construction-time factories and generic persistence schemas, then seals when a schedule is constructed. Each factory returns an immutable source-linked `WVForcing` that owns typed configuration and derived operators and is called once per forcing stage or constraint pass. The engine, integrators, reader, writer, and checkpoint code contain no forcing-class switch, and no string lookup occurs in coefficient or grid loops.

See the website's portable-runtime user and developer pages for the supported compatibility profile and extension boundaries.
