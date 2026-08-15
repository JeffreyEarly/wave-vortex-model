---
layout: default
title: Portable constant-stratification runtime
parent: User guide
nav_order: 5
---

# Portable constant-stratification runtime

WaveVortexModel includes an optional MATLAB-independent runtime for advanced constant-stratification workflows. MATLAB remains the primary interface. The portable program can restore a supported saved `WVModel` graph, continue its observing systems and output schedules in place, and produce MATLAB-compatible restart data without distributing a binary.

## Supported scope

The runtime supports hydrostatic and nonhydrostatic constant stratification, fixed-step RK4, adaptive Bogacki--Shampine RK3(2), and continuous output derived from each method's Runge--Kutta stages. Its frozen forcing subset is:

- `WVNonlinearAdvection`
- `WVAdaptiveDamping`
- `WVFixedAmplitudeForcing`
- `WVBottomFrictionQuadratic`
- `WVPseudoTopographicWaveGeneration`
- `WVBetaPlanePVAdvection`

Its qualified built-in observer records are `WVCoefficients`, `WVEulerianFields`, `WVMooring`, `WVLagrangianParticles`, and `WVTracer`. Arbitrary MATLAB subclasses are rejected before execution. Multi-file, named-group output is a C++ library capability, not a command-line configuration interface.

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

## Run and restart

Complete-model continuation is the default restart mode. It restores the selected file's dynamics mode, forcing order, output groups and schedules, shared observer identities, particles, tracers, committed progress, and latest complete state. Runtime integrator objects are not persisted, matching `WVModel.modelFromFile`; select fixed RK4 or adaptive RK3(2) for the continuation. A final time bounds the restored schedules:

```sh
wave-vortex-run saved-model.nc \
    --restart-mode model \
    --delta-t 1 --final-time 100 \
    --fft-provider native-fftw --threads 18

wave-vortex-run saved-model.nc \
    --restart-mode model \
    --integrator adaptive-rk23 \
    --delta-t 1 --final-time 100 \
    --relative-tolerance 1e-3 --absolute-tolerance 1e-6 \
    --fft-provider native-fftw
```

For a deliberately coefficient-only workflow, name that reduced boundary explicitly and supply a new checkpoint destination:

```sh
wave-vortex-run input.nc output.nc \
    --restart-mode coefficients \
    --delta-t 1 --steps 8 \
    --fft-provider native-fftw --threads 18
```

The output is restartable by the documented MATLAB and C++ readers. Plans, caches, continuous-output history, derived forcing operators, and scratch are rebuilt rather than persisted. Unsupported model graphs are rejected during allocation-light preflight, before the numerical core is constructed or output is opened for append.

The command-line program is intentionally small. Use MATLAB's `WVModel` for general forcing, custom observing systems, interactive configuration, and ordinary model output.
