# WaveVortex portable runtime

This directory contains the optional, MATLAB-independent constant-stratification runtime. MATLAB remains WaveVortexModel's primary interface. The portable runtime is a source-only checkpoint-to-checkpoint tool for advanced users and a C++ extension surface for future numerical methods and observing systems.

The runtime supports:

- fixed-step RK4 and adaptive Bogacki--Shampine RK3(2), including continuous output derived from each method's Runge--Kutta stages;
- the frozen v1 forcing subset (`WVNonlinearAdvection`, `WVAdaptiveDamping`, `WVFixedAmplitudeForcing`, `WVBottomFrictionQuadratic`, `WVPseudoTopographicWaveGeneration`, and `WVBetaPlanePVAdvection`);
- the five qualified built-in observer records (`WVCoefficients`, `WVEulerianFields`, `WVMooring`, `WVLagrangianParticles`, and `WVTracer`);
- MATLAB-compatible checkpoint and time-series NetCDF data for the documented constant-stratification subset.

Arbitrary MATLAB forcing or observing-system subclasses are not supported. Multi-file, named-group observing-system output is available through the C++ library; the command-line program intentionally exposes only checkpoint-to-checkpoint execution.

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

## Run and restart

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

Use `--restart-mode coefficients --output-policy create` with positional input and output paths for an explicit reduced checkpoint-only workflow. `create` refuses existing files; `replace` must be named to authorize atomic replacement. Complete-model continuation accepts only `append` and validates compatibility before mutation.

Plans, caches, integrator history, derived forcing operators, and scratch are rebuilt after restart rather than persisted.

## Architecture

`WVIntegrationStateLayout` describes canonical `Ap`, `Am`, and `A0` plus any observer-owned state blocks. `WVIntegrationSystem` supplies the right-hand side and constraints, `WVTimeIntegrator` advances accepted state, and `WVDenseOutput` evaluates within an accepted step. Output orchestration depends only on those contracts, so another integrator or state block does not require changes to the driver.

`WVObserverFactoryRegistry` is the source-level extension point for supported observer records. A registration selects reusable state and output contracts that are honored consistently by validation, evaluation, and persistence; the five built-ins use the same path. `WVFieldEvaluationService` shares primitive field reconstruction across observers, and `WVModelOutputNetCDFSink` owns transactional MATLAB-compatible persistence. The numerical kernel has no MATLAB, MEX, NetCDF, or Apple API dependency.

Registrations include the exact paired MATLAB/C++ identity and contract version and must be installed before the first observer descriptor is constructed. Descriptor construction seals the registry; integration performs no registration discovery or class-name lookup.

See the website's portable-runtime user and developer pages for the supported compatibility profile and extension boundaries.
