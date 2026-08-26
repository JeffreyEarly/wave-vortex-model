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

The end-to-end runtime supports hydrostatic and nonhydrostatic constant stratification, fixed-step RK4, MATLAB `ode23`-compatible Bogacki--Shampine integration, MATLAB `ode45`-compatible Dormand--Prince integration, and endpoint-only MATLAB `ode78`-compatible Verner integration. The accepted solutions are third order for `adaptive-rk23`, fifth order for `adaptive-rk45`, and eighth order for `adaptive-rk78`; their embedded error estimates are second, fourth, and seventh order, respectively. RK23 and RK45 provide continuous output from their Runge--Kutta stages. Issue #284 owns RK78 continuous output. The source tree also contains a MATLAB-matched Barotropic QG numerical kernel and compact `A0` integration system, but it is not yet connected to `WVModel`, observers, output, or restart and therefore is not selectable through the command-line workflows on this page. The end-to-end runtime's frozen forcing subset is:

- `WVNonlinearAdvection`
- `WVAdaptiveDamping`
- `WVFixedAmplitudeForcing`
- `WVBottomFrictionQuadratic`
- `WVBottomFrictionLinear`
- `WVPseudoTopographicWaveGeneration`
- `WVBetaPlanePVAdvection`

Its qualified built-in observer records are `WVCoefficients`, `WVEulerianFields`, `WVMooring`, `WVLagrangianParticles`, and `WVTracer`. Arbitrary MATLAB subclasses are rejected before execution. MATLAB authors multi-file, named-group output; the C++ command line executes that recovered graph without independently configuring it.

The tested interoperability boundary includes linear and nonlinear dynamics, the frozen forcing types listed above in their persisted execution order, fixed RK4, `adaptive-rk23`, `adaptive-rk45`, endpoint-only `adaptive-rk78`, evenly spaced output groups, shared observer identities, particle and tracer state, and in-place append progress. Other transform families, custom forcing or observer subclasses, two-dimensional tracers, and newly configured multi-file graphs are rejected before execution. There is no silent fallback to a reduced checkpoint or MATLAB implementation.

The stabilized C++ boundary is `wave-vortex-portable-source-api-v1`, version 1.0. It supports statically linked extensions and reusable-runner applications built from one explicitly selected WaveVortexModel checkout. Change the checkout only as a deliberate dependency update, then recompile the runtime, every extension, and the runner together. This is source compatibility, not a binary plug-in ABI: there is no dynamic discovery, separately loadable extension, cross-build binary compatibility, or distributed runtime binary. Scientific and persisted pair, schedule, observation-schema, run-request, and kernel versions are independent and must each match exactly.

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

The reference runtime and source-linked applications are qualified on Ubuntu with GCC or Clang and on macOS with AppleClang. The optimized FFTW runner above is limited to Apple silicon. WaveVortexModel does not currently compile under MSVC, so Windows source-linked runtime applications are unsupported.

## Run a MATLAB-authored model bundle

The portable boundary intentionally separates scientific state from execution choices:

- The NetCDF file set is authoritative for model configuration, state, forcing, observers, output membership, schedules, and restart progress.
- A versioned JSON request names those files and selects the integrator, final time, output destinations, FFT provider, threads, and report path.

Starting from output files created by MATLAB, copy `PortableRuntime/examples/portable-run-request-v1.json`, list every sibling file needed to reconstruct the graph, and map each stable file identifier to a destination. Then run:

```sh
wave-vortex-run --request portable-run-request-v1.json
```

Relative paths are interpreted relative to the JSON file. `create` and `replace` require a complete destination map and cannot alias a source file. `append` may use the existing destinations with an empty map, or it may provide a complete map to an existing compatible set. The runner rejects unknown JSON fields, incomplete sibling sets, unsupported paired implementations, incompatible graphs, and invalid destinations before constructing the FFT provider, allocating model state, advancing integration, or mutating output.

The request describes execution, not another model. It cannot change forcing, observers, groups, schedules, or state. Copy the committed example or use a package-specific MATLAB authoring helper; AlongTrackSimulator's `authorAlongTrackPortableRunBundle` is one external example. The exact v1 schema is committed at `PortableRuntime/contracts/wave-vortex-run-request-v1.schema.json`.

## Source-linked extensions

An application owns its extension catalog. It adds WaveVortexModel's built-ins, adds every source-linked observer, schedule, and forcing before freezing, freezes once, and passes the immutable shared catalog to `runWaveVortex()`. Runtime owners retain that catalog for as long as resolved implementations depend on it, so the mutable builder and the caller's original shared pointer can be destroyed. Independent catalogs can coexist and can bind the same source identity differently without process-global state.

The completed [AlongTrackSimulator ATS #4 integration](https://github.com/satmapkit/AlongTrackSimulator/commit/ba57981f336ad5bbbc0907dcd74fcd4fcd137708) is the real external-consumer baseline. Final source API qualification rebuilds its extended runner against the explicitly selected WaveVortexModel checkout and runs a MATLAB-authored bundle that combines `WVAlongTrackSchedule` and `WVAlongTrackObservingSystem` with built-in `WVBottomFrictionLinear`. The base runner rejects the external pair during preflight, while the extended runner accepts the same bundle. Qualification covers repeating and nonrepeating/geodetic passes, fixed and adaptive integration, exact and dense output, create/replace/append, restart and continuation, retry, source immutability, and MATLAB parity without adding AlongTrack-specific runtime dispatch.

## Legacy run and restart

The original single-file command remains supported. Complete-model continuation restores the selected file's dynamics mode, forcing order, output groups and schedules, shared observer identities, particles, tracers, committed progress, and latest complete state. Runtime integrator objects are not persisted, matching `WVModel.modelFromFile`; select fixed RK4, `adaptive-rk23`, or `adaptive-rk45` for a continuation that needs restored output schedules. Endpoint-only `adaptive-rk78` is available for explicit coefficient-only checkpoint continuation until #284 supplies its continuous extension. A final time bounds the restored schedules:

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

wave-vortex-run saved-model.nc \
    --restart-mode model \
    --output-policy append \
    --integrator adaptive-rk45 \
    --delta-t 1 --initial-step 1 --maximum-step 10 --final-time 100 \
    --relative-tolerance 1e-3 --absolute-tolerance 1e-6 \
    --fft-provider native-fftw
```

For adaptive methods, `--delta-t` is the backward-compatible default initial step and `--initial-step` makes that request explicit. Unless `--maximum-step` is supplied, the runtime limits accepted steps to one tenth of the requested continuation interval, matching MATLAB's default bound. Specify both controls for reproducible segmented runs and benchmark comparisons. The runtime uses MATLAB-compatible componentwise relative/absolute error scaling and preserves each observing-system state's own absolute tolerance. `adaptive-rk23` preserves the existing MATLAB `ode23` controller, continuous extension, restart, and diagnostic contract exactly. `adaptive-rk45` advances with the Dormand--Prince fifth-order solution, controls error with the embedded fourth-order estimate, and uses MATLAB `ode45` FSAL, rejection, final-step, and continuous-output semantics. `adaptive-rk78` advances with Verner's eighth-order solution, controls error with the embedded seventh-order estimate, and matches MATLAB `ode78` rejection, final-step, and RHS-work semantics without unsafe derivative reuse. Its 11 state-equivalent workspace retains only `f1`, `f6` through `f12`, the transient stage buffers, and the accepted-state buffer; the four dense-extension-only stages remain absent. The strict run-request-v1 JSON contract remains fixed to RK4 and `adaptive-rk23`; use the legacy command form or C++ source API for `adaptive-rk45` and endpoint-only `adaptive-rk78` until a later versioned request contract adds them.

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

Arbitrary MATLAB subclass execution, real state-triggered schedules, multiple model-state samples within one occurrence, dynamic or binary plug-ins, distributed compiled products, and Windows/MSVC source-linked execution are outside the supported contract. Unsupported identities, versions, graphs, and platforms fail explicitly rather than falling back to MATLAB.
