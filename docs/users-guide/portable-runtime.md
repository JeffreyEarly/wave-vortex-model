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

The end-to-end runtime supports hydrostatic and nonhydrostatic constant stratification, fixed-step RK4, MATLAB `ode23`-compatible Bogacki--Shampine integration, MATLAB `ode45`-compatible Dormand--Prince integration, and MATLAB `ode78`-compatible Verner integration. The accepted solutions are third order for `adaptive-rk23`, fifth order for `adaptive-rk45`, and eighth order for `adaptive-rk78`; their embedded error estimates are second, fourth, and seventh order, respectively. All three adaptive methods provide method-owned continuous output; RK78 uses Verner's seventh-order continuous extension and computes its four additional stages only for accepted steps that contain an interior output request. The source tree also contains a MATLAB-matched Barotropic QG numerical kernel and compact `A0` integration system, but it is not yet connected to `WVModel`, observers, output, or restart and therefore is not selectable through the command-line workflows on this page. The end-to-end runtime's frozen forcing subset is:

- `WVNonlinearAdvection`
- `WVAdaptiveDamping`
- `WVFixedAmplitudeForcing`
- `WVBottomFrictionQuadratic`
- `WVBottomFrictionLinear`
- `WVPseudoTopographicWaveGeneration`
- `WVBetaPlanePVAdvection`

Its qualified built-in observer records are `WVCoefficients`, `WVEulerianFields`, `WVMooring`, `WVLagrangianParticles`, and `WVTracer`. Arbitrary MATLAB subclasses are rejected before execution. MATLAB authors multi-file, named-group output; the C++ command line executes that recovered graph without independently configuring it.

The tested interoperability boundary includes linear and nonlinear dynamics, the frozen forcing types listed above in their persisted execution order, fixed RK4, `adaptive-rk23`, `adaptive-rk45`, `adaptive-rk78` with seventh-order continuous output, evenly spaced output groups, shared observer identities, particle and tracer state, and in-place append progress. Other transform families, custom forcing or observer subclasses, two-dimensional tracers, and newly configured multi-file graphs are rejected before execution. There is no silent fallback to a reduced checkpoint or MATLAB implementation.

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

The complete authoring workflow is:

1. Construct the initial conditions, forcing, observers, output files, groups, and schedules in MATLAB.
2. Integrate through the initial output time and close the model so every sibling NetCDF file contains an initial committed record.
3. Call `WVModel.writePortableRunRequest` with the ordered complete file set and execution choices.
4. Execute the resulting request with `wave-vortex-run --request`.
5. Restore or continue the resulting NetCDF bundle from MATLAB when needed.

For example, exact v1 MATLAB `ode23` selection with in-place append is:

```matlab
model.integrateToTime(model.t,shouldShowIntegrationDiagnostics=false);
model.closeNetCDFFile();
WVModel.writePortableRunRequest("run-v1.json","saved-model.nc",schemaVersion=1,method="adaptive-rk23",finalTime=86400,initialStep=10,maximumStep=3600,relativeTolerance=1e-3,absoluteToleranceScale=1e-6,outputPolicy="append",fftProvider="native-fftw",threads=8,reportPath="run-v1-report.json");
```

Version 2 adds explicit or CFL-selected RK4 and MATLAB `ode45` and `ode78`. A create request for an RK78 continuation can remap every output file by its stable identifier:

```matlab
destinations = configureDictionary("string","string");
destinations("primary") = "continued model.nc";
WVModel.writePortableRunRequest("run-v2.json","saved-model.nc",schemaVersion=2,method="adaptive-rk78",finalTime=172800,initialStep=10,maximumStep=3600,relativeTolerance=1e-6,absoluteToleranceScale=1e-9,outputPolicy="create",destinations=destinations,fftProvider="native-fftw",threads=8);
```

The writer obtains identifiers and compatibility facts through NetCDF metadata inspection; it does not reconstruct the model or read coefficient and observer-state arrays. Files authored by the portable runtime carry `portableFileIdentifier`. For legacy MATLAB files without that attribute, the runtime-compatible identifier is derived from the resolved source path, and an incomplete-map diagnostic lists the exact identifiers required. Destination entries are serialized in identifier order while the supplied `modelFiles` order is preserved exactly.

Run the generated request with:

```sh
wave-vortex-run --request run-v2.json
```

Relative paths are interpreted relative to the JSON file. `create` and `replace` require a complete destination map and cannot alias a source file. `append` may use the existing destinations with an empty map, or it may provide a complete map to an existing compatible set. The runner rejects unknown JSON fields, incomplete sibling sets, unsupported paired implementations, incompatible graphs, and invalid destinations before constructing the FFT provider, allocating model state, advancing integration, or mutating output.

Run-request v2 has five mutually exclusive integration forms. Fixed RK4 accepts either a positive explicit `initialStep`, or a positive `cfl` together with `timeStepConstraint` set to `advective`, `oscillatory`, or `min`. MATLAB `ode23`, `ode45`, and `ode78` are serialized as `adaptive-rk23`, `adaptive-rk45`, and `adaptive-rk78`; each requires explicit initial step, maximum step, relative tolerance, and absolute-tolerance scale. The runner resolves the method and step policy once and never substitutes another implementation. Choose among MATLAB `ode23`, `ode45`, and `ode78` from measured accepted/rejected steps, RHS work, dense-output work, and wall time for the intended model and output schedule rather than from formal order alone.

A CFL-selected RK4 request evaluates the transform-owned candidates once after restoring the segment's initial state. The advective candidate uses the effective horizontal resolution and maximum horizontal speed and, for three-dimensional transforms, the vertical `dz/w` restriction. The oscillatory candidate uses the highest active wave frequency; transforms without waves report infinity. The selected step is fixed for that segment, apart from the existing final partial step, and is not recomputed at RK stages or output events. Reports identify every candidate, the selected step, transient CFL workspace, requested and active method, controller, step policy, FFT provider, accepted/rejected steps, base and dense-output RHS work, exact integrator storage, parse/preflight/provider/startup timing, and the no-fallback result.

JSON plus every referenced NetCDF sibling forms the complete execution request. JSON does not independently describe the scientific model and cannot change forcing, observers, groups, schedules, restart progress, or state. `WVModel.writePortableRunRequest` constructs v1 and v2 separately, rejects irrelevant controls and path aliases before writing, re-reads its UTF-8 document, and installs it by transactional sibling replacement. Existing v1 documents retain their exact fixed-RK4 and MATLAB `ode23` decoding, execution, report, and error behavior; v2 fields and defaults are never applied to v1, and the positional legacy CLI is unchanged. The exact schemas remain committed at `PortableRuntime/contracts/wave-vortex-run-request-v1.schema.json` and `PortableRuntime/contracts/wave-vortex-run-request-v2.schema.json`.

## Source-linked extensions

An application owns its extension catalog. It adds WaveVortexModel's built-ins, adds every source-linked observer, schedule, and forcing before freezing, freezes once, and passes the immutable shared catalog to `runWaveVortex()`. Runtime owners retain that catalog for as long as resolved implementations depend on it, so the mutable builder and the caller's original shared pointer can be destroyed. Independent catalogs can coexist and can bind the same source identity differently without process-global state.

The completed [AlongTrackSimulator ATS #4 integration](https://github.com/satmapkit/AlongTrackSimulator/commit/ba57981f336ad5bbbc0907dcd74fcd4fcd137708) is the real external-consumer baseline. Final source API qualification rebuilds its extended runner against the explicitly selected WaveVortexModel checkout and runs a MATLAB-authored bundle that combines `WVAlongTrackSchedule` and `WVAlongTrackObservingSystem` with built-in `WVBottomFrictionLinear`. The base runner rejects the external pair during preflight, while the extended runner accepts the same bundle. Qualification covers repeating and nonrepeating/geodetic passes, fixed and adaptive integration, exact and dense output, create/replace/append, restart and continuation, retry, source immutability, and MATLAB parity without adding AlongTrack-specific runtime dispatch.

## Legacy run and restart

The original single-file command remains supported. Complete-model continuation restores the selected file's dynamics mode, forcing order, output groups and schedules, shared observer identities, particles, tracers, committed progress, and latest complete state. Runtime integrator objects are not persisted, matching `WVModel.modelFromFile`; select fixed RK4, `adaptive-rk23`, `adaptive-rk45`, or `adaptive-rk78` for continuation with restored output schedules. A final time bounds the restored schedules:

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

For adaptive methods, `--delta-t` is the backward-compatible default initial step and `--initial-step` makes that request explicit. Unless `--maximum-step` is supplied, the runtime limits accepted steps to one tenth of the requested continuation interval, matching MATLAB's default bound. Specify both controls for reproducible segmented runs and benchmark comparisons. The runtime uses MATLAB-compatible componentwise relative/absolute error scaling and preserves each observing-system state's own absolute tolerance. `adaptive-rk23` preserves the existing MATLAB `ode23` controller, continuous extension, restart, and diagnostic contract exactly. `adaptive-rk45` advances with the Dormand--Prince fifth-order solution, controls error with the embedded fourth-order estimate, and uses MATLAB `ode45` FSAL, rejection, final-step, and continuous-output semantics. `adaptive-rk78` advances with Verner's eighth-order solution, controls error with the embedded seventh-order estimate, and matches MATLAB `ode78` rejection, final-step, and RHS-work semantics without unsafe derivative reuse. Its endpoint-only path uses the existing 11 state-equivalent base workspace and performs no extension evaluation or allocation. An interior request lazily adds four state-equivalent buffers for `f14` through `f17`; the method evaluates them once per accepted step, reuses them for all samples in that step, and releases them before advancing. Exact endpoint requests bypass the extension. Base and extension RHS work, retained base stages, current and maximum extension workspace, maximum-live arrays, dense evaluations, cache reuse, and timing are reported separately. Run-request v1 remains fixed to RK4 and MATLAB `ode23`; run-request v2 adds exact MATLAB `ode45` and `ode78` selection plus explicit or CFL-selected RK4.

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
