---
layout: default
title: Portable constant-stratification runtime
parent: User guide
nav_order: 5
---

# Portable constant-stratification runtime

WaveVortexModel includes an optional MATLAB-independent runtime for advanced constant-stratification workflows. MATLAB remains the primary interface. The portable program can restore a supported saved `WVModel` graph, continue its observing systems and output schedules in place, and produce MATLAB-compatible restart data without distributing a binary.

There are two distinct compiled paths. Within MATLAB, select the [compiled nonlinear-flux preview](/users-guide/compiled-preview.html) by constructing a compatible transform with `computationalBackend="compiled"`; the rest of `WVModel` remains MATLAB. The standalone path described here starts at a saved model-output file, runs integration and supported observers outside MATLAB, and writes the same file so MATLAB can resume with `WVModel.modelFromFile`.

## Supported scope

The runtime supports hydrostatic and nonhydrostatic constant stratification, fixed-step RK4, adaptive Bogacki--Shampine RK3(2), and continuous output derived from each method's Runge--Kutta stages. Its frozen forcing subset is:

- `WVNonlinearAdvection`
- `WVAdaptiveDamping`
- `WVFixedAmplitudeForcing`
- `WVBottomFrictionQuadratic`
- `WVPseudoTopographicWaveGeneration`
- `WVBetaPlanePVAdvection`

Its qualified built-in observer records are `WVCoefficients`, `WVEulerianFields`, `WVMooring`, `WVLagrangianParticles`, and `WVTracer`. Arbitrary MATLAB subclasses are rejected before execution. MATLAB authors multi-file, named-group output; the C++ command line executes that recovered graph without independently configuring it.

The tested interoperability boundary includes linear and nonlinear dynamics, the frozen forcing types listed above in their persisted execution order, fixed RK4 and adaptive RK3(2), evenly spaced output groups, shared observer identities, particle and tracer state, and in-place append progress. Other transform families, custom forcing or observer subclasses, two-dimensional tracers, and newly configured multi-file graphs are rejected before execution. There is no silent fallback to a reduced checkpoint or MATLAB implementation.

## Build from source

On Apple silicon, run:

```sh
PortableRuntime/buildWaveVortexRun.sh
```

The script downloads the official FFTW 3.3.11 archive, verifies its checksum, and builds FFTW and `wave-vortex-run` in the ignored `.compiled-backend-cache`. WaveVortexModel distributes no FFTW archive, library, MEX file, executable, or other compiled product. Redistributing a locally linked executable requires compliance with FFTW's GPL license.

A portable correctness build using the reference transform engine requires CMake 3.20, a C++17 compiler, and NetCDF C:

```sh
cmake -S PortableRuntime -B build/portable -DCMAKE_BUILD_TYPE=Release
cmake --build build/portable --parallel
ctest --test-dir build/portable --output-on-failure
```

## Run a MATLAB-authored model bundle

The portable boundary intentionally separates scientific state from execution choices:

- The NetCDF file set is authoritative for model configuration, state, forcing, observers, output membership, schedules, and restart progress.
- A versioned JSON request names those files and selects the integrator, final time, output destinations, FFT provider, threads, and report path.

Starting from output files created by MATLAB, copy `PortableRuntime/examples/portable-run-request-v1.json`, list every sibling file needed to reconstruct the graph, and map each stable file identifier to a destination. Then run:

```sh
wave-vortex-run --request portable-run-request-v1.json
```

Relative paths are interpreted relative to the JSON file. `create` and `replace` require a complete destination map and cannot alias a source file. `append` may use the existing destinations with an empty map, or it may provide a complete map to an existing compatible set. The runner rejects unknown JSON fields, incomplete sibling sets, unsupported paired implementations, incompatible graphs, and invalid destinations before constructing the FFT provider, allocating model state, advancing integration, or mutating output.

The request describes execution, not another model. It cannot change forcing, observers, groups, schedules, or state. A future MATLAB API will generate this request automatically; the v1 schema is committed at `PortableRuntime/contracts/wave-vortex-run-request-v1.schema.json`.

## Legacy run and restart

The original single-file command remains supported. Complete-model continuation restores the selected file's dynamics mode, forcing order, output groups and schedules, shared observer identities, particles, tracers, committed progress, and latest complete state. Runtime integrator objects are not persisted, matching `WVModel.modelFromFile`; select fixed RK4 or adaptive RK3(2) for the continuation. A final time bounds the restored schedules:

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

For adaptive RK3(2), `--delta-t` is the backward-compatible default initial step and `--initial-step` makes that request explicit. Unless `--maximum-step` is supplied, the runtime limits accepted steps to one tenth of the requested continuation interval, matching MATLAB `ode23`. Specify both controls for reproducible segmented runs and benchmark comparisons. The runtime uses MATLAB-compatible componentwise relative/absolute error scaling and preserves each observing-system state's own absolute tolerance.

For a deliberately coefficient-only workflow, name that reduced boundary explicitly and supply a new checkpoint destination:

```sh
wave-vortex-run input.nc output.nc \
    --restart-mode coefficients \
    --output-policy create \
    --delta-t 1 --steps 8 \
    --fft-provider native-fftw --threads 18
```

The output policy is always explicit. `append` is valid only for complete-model continuation and retains earlier compatible records. `create` refuses an existing coefficient-checkpoint destination. Use `replace` instead of `create` only when replacement is intentional; the writer validates a temporary checkpoint before atomically committing it. Input/output aliases are rejected, and validation or integration failures leave existing files recoverable.

The output is restartable by the documented MATLAB and C++ readers. Plans, caches, continuous-output history, derived forcing operators, and scratch are rebuilt rather than persisted. Unsupported model graphs are rejected during allocation-light preflight, before the numerical core is constructed or output is opened for append.

Return to MATLAB after standalone continuation with:

```matlab
model = WVModel.modelFromFile("saved-model.nc");
```

The mandatory compatibility test performs this MATLAB-to-standalone-to-MATLAB round trip and compares the graph, state, schedules, output ordinals, particles, and tracer. Future `WVModel` features enter the standalone runtime by extending these shared graph contracts rather than bypassing them.

The command-line program is intentionally small. Use MATLAB's `WVModel` to author initial conditions, forcing, observing systems, and output graphs; use the request only to execute a supported portable bundle.
