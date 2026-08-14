---
layout: default
title: Portable constant-stratification runtime
parent: User guide
nav_order: 5
---

# Portable constant-stratification runtime

`wave-vortex-run` advances a compatible WaveVortexModel checkpoint without starting MATLAB. It uses the same MATLAB-independent constant-stratification C++ core as the compiled MATLAB preview, the frozen forcing schedule stored in the checkpoint, and either deterministic fixed-step RK4 or adaptive Bogacki--Shampine RK3(2) integration.

The runner is source-only. The optimized provider currently targets Apple silicon and builds the pinned FFTW 3.3.11 NEON/pthreads configuration locally. No FFTW library or executable is distributed by WaveVortexModel.

## Build

From an authoring checkout on Apple silicon:

```sh
tools/portable-runtime/buildWaveVortexRun.sh
```

The script downloads the official FFTW archive only when the ignored local cache does not already contain it, verifies the recorded SHA-256 checksum, and builds `wave-vortex-run` under `.compiled-backend-cache`. Use the resulting path printed on the final line.

A portable reference build is available for correctness and non-Apple development:

```sh
cmake -S PortableRuntime -B build/portable-runtime -DCMAKE_BUILD_TYPE=Release
cmake --build build/portable-runtime --target wave-vortex-run
```

The reference provider is intentionally not the optimized runtime.

## Run and restart

Select the FFT provider explicitly and specify either a step count or a final time:

```sh
wave-vortex-run restart.nc continued.nc \
  --delta-t 1 \
  --steps 100 \
  --fft-provider native-fftw \
  --threads 18 \
  --report continued.json
```

or:

```sh
wave-vortex-run restart.nc continued.nc \
  --delta-t 1 \
  --final-time 3600 \
  --fft-provider native-fftw
```

If the requested final time is not an integer number of steps from the checkpoint time, the last step is shortened. Input and output may name the same file; replacement is transactional and a failed run preserves the prior checkpoint.

Select adaptive RK3(2) explicitly when error-controlled steps are preferred:

```sh
wave-vortex-run restart.nc continued.nc \
  --integrator adaptive-rk23 \
  --delta-t 1 \
  --final-time 3600 \
  --relative-tolerance 1e-3 \
  --absolute-tolerance 1e-6 \
  --fft-provider native-fftw
```

For adaptive execution, `--delta-t` is the initial proposal and `--steps` counts accepted steps. The absolute value is an energy-scale tolerance converted into mode-dependent coefficient tolerances using the same convention as MATLAB `WVCoefficients.errorTolerances`. Rejected attempts do not emit output or alter accepted state. Controller and FSAL state are derived runtime data, so a restart is tolerance-equivalent rather than bitwise trajectory-equivalent.

## Scheduled restart checkpoints

Use repeated `--output-time` options to write several individually restartable checkpoints without forcing solver steps to end at those times:

```sh
wave-vortex-run restart.nc \
  --integrator adaptive-rk23 \
  --delta-t 1 \
  --final-time 3600 \
  --output-time 900 \
  --output-time 1800 \
  --output-time 3600 \
  --output-directory checkpoints \
  --output-pattern 'restart-{index}-{time}.nc' \
  --fft-provider native-fftw
```

Scheduled mode uses `--final-time` and omits the positional output file. Only explicitly requested times are written. The default pattern is `checkpoint-{index}.nc`, where `{index}` is a one-based, six-digit ordinal; `{time}` expands to the round-trip-safe requested time. A pattern must be a `.nc` filename containing at least one of these tokens.

The output directory is created when necessary. Every destination is validated before the coefficient arrays and numerical backend are constructed, and scheduled output never replaces an existing path. Each checkpoint is written and validated transactionally, so interruption or a later write failure leaves the input and all earlier checkpoints intact.

These files use the same root-level WaveVortexModel 4.x restart profile as ordinary single output. MATLAB and the portable runtime can read and continue each file. They are separate scalar restart checkpoints, not a multi-time MATLAB observing-system output file.

The runner never chooses another FFT provider or omits unsupported forcing. A native provider request fails clearly if the executable was not built with the validated FFTW provider. Unsupported transforms, checkpoint structures, and forcing schedules are rejected before the three coefficient arrays are loaded.

## Supported scope

Runtime v1 supports hydrostatic and nonhydrostatic constant stratification, transform-level antialiasing, and frozen schedules containing:

- `WVNonlinearAdvection`;
- `WVAdaptiveDamping`;
- `WVFixedAmplitudeForcing`;
- `WVBottomFrictionQuadratic`;
- `WVPseudoTopographicWaveGeneration`;
- `WVBetaPlanePVAdvection`.

Custom forcing and all other forcing classes remain in MATLAB. See the [portable checkpoint profile](/developers-guide/portable-checkpoint-profile.html) for the exact state, forcing, and restart contract.

The portable-output contract is documented in the [portable observing-system contract](/developers-guide/portable-observing-system-contract.html). The library evaluates and persists coefficient, Eulerian-field, fixed-mooring, integrated Lagrangian-particle, and three-dimensional tracer observers with MATLAB-compatible names, dimensions, metadata, interpolation, and cadence. Particle coordinates and `[Nx,Ny,Nz]` tracer values participate in fixed RK4 or adaptive RK3(2) integration and method-owned dense output. Horizontal particle coordinates remain unwrapped in state while field interpolation is periodic. Tracer differentiation and optional antialiasing use the same compiled numerical core as nonlinear advection, and all integrated observers share its per-RHS velocity reconstruction. Two-dimensional tracer integration is not yet supported by the constant-stratification runtime.

All five built-in observer types are qualified for runtime-to-MATLAB and MATLAB-to-runtime restart, continuation, and append through the portable C++ library. This includes multiple simultaneous files, differently scheduled groups, shared particle or tracer identities, fixed RK4, and adaptive RK3(2). The compatibility guarantee does not extend to custom observing-system subclasses or other transform families.

The current overall readiness record is `PARTIAL`: numerical and file compatibility pass, while one medium nonhydrostatic output-disabled performance case exceeded the 3% non-regression threshold by about one percentage point. This does not change the supported compatibility subset, but it prevents a full readiness claim until that small regression is resolved or deliberately accepted.

The standalone `wave-vortex-run` executable remains intentionally narrower: its command-line interface reads and writes scalar restart checkpoints and scheduled scalar checkpoints. Multi-file observing-system output is currently a library API, not a command-line configuration feature. This distinction keeps the lightweight restart workflow stable while the portable observer graph develops independently.

## Reports and performance

Every invocation writes a structured JSON record to standard output. `--report` writes the same record to a file. It includes the resolved forcing order, provider and loaded-library identities, plan count, integration and checkpoint timings, known application-owned storage, and the active execution schedule. Scheduled runs also report each requested and emitted time, exact-endpoint or interpolated status, destination, write duration, and partial failure.

Runtime readiness uses the time spent in eight fixed RK4 integration steps. Startup, checkpoint reading, provider construction, preparation, and output writing are reported separately and do not enter the integration-speed gate. Runtime memory is also reported separately and does not change numerical compatibility.
