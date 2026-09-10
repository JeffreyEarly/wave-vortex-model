---
layout: default
title: Standalone portable runtime
parent: Compiled execution
nav_order: 2
permalink: /users-guide/portable-runtime.html
---

# Standalone portable runtime

The standalone runtime continues a supported MATLAB-authored `WVModel` graph in a separate process. MATLAB defines the initial conditions, transform, forcing, observers, output groups, schedules, and restart state. NetCDF remains the authoritative scientific record; a small JSON file contains execution and routing choices.

## Minimal MATLAB-to-standalone workflow

Once MATLAB has written and closed a restart-capable model-output file, the default request needs only the destination JSON path, the NetCDF path, and a final time:

```matlab
WVModel.writePortableRunRequest("run.json","initial-condition.nc",finalTime=86400);
```

From the WaveVortexModel repository root, build the native runner:

```sh
PortableRuntime/buildWaveVortexRun.sh
```

The build writes the executable into the ignored local cache. Run the generated request without editing it by invoking that exact path:

```sh
.compiled-backend-cache/runtime-build/wave-vortex-run --request run.json
```

Run-request v2 supplies the standard WaveVortexModel defaults when they are omitted:

| Setting | Resolved default |
| --- | --- |
| Schema | `wave-vortex-run-request-v2` |
| Integrator | MATLAB `ode78`, serialized as `adaptive-rk78` |
| Relative tolerance | `1e-3` |
| Absolute-tolerance scale | `1e-6` |
| Initial step | Minimum advective/oscillatory step at CFL `0.5`, evaluated after restoring the selected state |
| Maximum step | One tenth of the requested continuation interval |
| FFT provider | Native FFTW |
| Threads | Hardware-bounded automatic count |

These reproduce standard `WVModel` behavior. They cannot recover custom MATLAB-session integrator settings that were never persisted. Every explicit request value overrides its default. Reports distinguish omitted or requested values from the active method, tolerances, steps, provider, and thread count.

If the native provider is unavailable, the runner stops with build instructions before state-sized runtime allocation, integration, state advancement, or output mutation. It never substitutes the reference provider. The reference provider remains available only when explicitly requested for correctness and development workflows.

## Supported scientific workflow

The runtime supports all five transform families, including hydrostatic and nonhydrostatic constant stratification. It preserves each transform's coefficient layout and supports explicit or CFL-selected RK4 plus MATLAB-compatible `ode23`, `ode45`, and `ode78`, including continuous output.

All twelve stable supplied forcing identities are implemented where MATLAB permits them. The five built-in observing systems support transform-specific coefficient, field, mooring, particle, and tracer layouts. Multi-file and named-group schedules are authored in MATLAB and executed without restating the science in JSON. The [generated compatibility matrix](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/PortableRuntime/COMPATIBILITY.md) identifies exact support, sampling restrictions, intentional incompatibilities, and their test fixtures.

Arbitrary MATLAB subclass or function-handle execution, backward integration, dynamic plug-ins, distributed binaries, and Windows/MSVC qualification remain outside this surface. Opaque MATLAB stratification functions remain preserved restart provenance. C++ extensions are compiled with the selected source checkout and have no binary plug-in ABI.

## Build and continue

On Apple silicon, build the pinned native runner with:

```sh
PortableRuntime/buildWaveVortexRun.sh
```

The script builds ignored local FFTW 3.3.11 libraries and `wave-vortex-run`. WaveVortexModel distributes no compiled product. Redistributing a linked runner requires compliance with FFTW's GPL license.

Restore an in-place continuation in MATLAB with:

```matlab
model = WVModel.modelFromFile("initial-condition.nc");
```

For complete destination remapping, multi-file bundles, explicit integration controls, schema-v1 compatibility, reference builds, and source-linked extensions, see [PortableRuntime/README.md](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/PortableRuntime/README.md) and the [portable-runtime contract](/developers-guide/portable-runtime-contract.html).
