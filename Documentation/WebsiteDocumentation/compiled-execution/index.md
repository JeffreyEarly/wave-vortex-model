---
layout: default
title: Compiled execution
nav_order: 9.5
has_children: true
permalink: /compiled-execution
---

# Compiled execution

WaveVortexModel has two optional source-built C++ paths. MATLAB remains the default authoring and execution environment. The paths share numerical kernels, but they solve different problems and have different process, persistence, and compatibility boundaries.

## Choose a path

| Boundary | [Compiled MATLAB backend](/users-guide/compiled-preview.html) | [Standalone portable runtime](/users-guide/portable-runtime.html) |
| --- | --- | --- |
| Process | Runs inside the MATLAB process through MEX | Runs as the separate `wave-vortex-run` process |
| Supported transforms | All six built-in v4 configurations, with qualified family operation sets | All five transform families |
| Numerical scope | Supported fields, transforms, derivatives, primitives, and native nonlinear calculations; MATLAB owns integration | Complete supported model integration and output |
| Integrators | MATLAB owns integration | Fixed RK4 and MATLAB-compatible `ode23`, `ode45`, and `ode78` |
| Forcing | MATLAB owns built-in and custom forcing orchestration; supported primitive calls may dispatch compiled | All twelve stable built-ins where MATLAB permits them |
| Observers and output | MATLAB owns them | Documented portable observers, schedules, and NetCDF output |
| Persistence | Backend selection is not persisted | MATLAB-authored NetCDF is continued and remains MATLAB-readable |
| Build | `WVCompiledBackend.build()` | `PortableRuntime/buildWaveVortexRun.sh` |
| Intended use | Accelerate supported numerical calls while the model remains in MATLAB | Continue a supported model outside MATLAB or embed the source runtime |

Both optimized paths currently require Apple silicon and a locally built pinned FFTW provider. WaveVortexModel distributes source, not FFTW libraries, MEX files, or runner executables. An explicit compiled request never silently falls back to another implementation.

Use the compiled MATLAB backend when the model should stay in MATLAB and its requested numerical operations are supported. Custom operations and forcing callbacks remain MATLAB code, and their supported primitive calls can still use the compiled path. Use the standalone runtime when MATLAB should author the initial conditions and scientific graph but a separate process should perform the supported integration and persistence workflow.

Detailed ownership, extension, numerical, and persistence contracts are documented in the [compiled-kernel contract](/developers-guide/compiled-kernel-contract.html) and [portable-runtime contract](/developers-guide/portable-runtime-contract.html).

See [Benchmarks](/benchmarks) for the accepted MATLAB, compiled-core, and standalone runtime measurements and MATLAB scaling results.
