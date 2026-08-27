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

Run the generated request without editing it:

```sh
wave-vortex-run --request run.json
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

The runtime supports hydrostatic and nonhydrostatic constant stratification and equivalent-barotropic QG. It preserves compact QG `A0` storage and supports fixed RK4 plus MATLAB-compatible `ode23`, `ode45`, and `ode78`, including their method-owned continuous output.

The qualified forcing set includes nonlinear advection, adaptive damping, fixed and narrow-band amplitudes, linear and quadratic bottom friction, beta-plane PV advection, and constant-stratification pseudo-topographic wave generation where transform-valid. Supported model graphs may contain coefficients, Eulerian fields, constant-stratification moorings, particles, and tracers within the documented transform-specific limits. Multi-file and named-group schedules are authored in MATLAB and executed without restating the science in JSON.

Unsupported transforms, arbitrary MATLAB subclasses, three-dimensional QG particles or tracers, QG moorings, later closures, dynamic plug-ins, and Windows/MSVC builds are rejected. The portable C++ extension boundary is source-compatible, not a binary plug-in ABI.

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

For complete destination remapping, multi-file bundles, explicit integration controls, schema-v1 compatibility, reference builds, and source-linked extensions, see [PortableRuntime/README.md](https://github.com/JeffreyEarly/wave-vortex-model/blob/feature/v4.3-portable-runtime/PortableRuntime/README.md) and the [portable-runtime contract](/developers-guide/portable-runtime-contract.html).
