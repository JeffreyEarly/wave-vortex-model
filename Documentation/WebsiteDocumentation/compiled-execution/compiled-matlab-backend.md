---
layout: default
title: Compiled MATLAB backend
parent: Compiled execution
nav_order: 1
permalink: /users-guide/compiled-preview.html
---

# Compiled MATLAB backend

The compiled MATLAB backend is an opt-in execution path for the six built-in v4 transform configurations. It runs supported transform, field, derivative, and native primitive calculations inside MATLAB through MEX. `WVModel`, integration, MATLAB orchestration, custom operations, forcing callbacks, observers, and NetCDF output remain MATLAB operations.

## Build and select it

On Apple silicon with MATLAB R2025b or later, inspect native support and build it explicitly when needed:

```matlab
capabilities = WVCompiledBackend.capabilities();
if ~capabilities.isAvailable
    capabilities = WVCompiledBackend.build();
end
```

`capabilities()` performs no download or compilation. `build()` downloads the official FFTW 3.3.11 source archive, verifies its checksum, and creates ignored local products.

Select the backend when constructing a compatible transform:

```matlab
wvt = WVTransformConstantStratification([15e3 15e3 1300],[256 256 65],computationalBackend="compiled");
[Fp,Fm,F0] = wvt.nonlinearFlux();
```

Construction validates the native provider, loaded FFTW libraries, numerical self-tests, and compiled-kernel contract. An explicit compiled request fails if any requirement is unavailable; it does not fall back to MATLAB.

## Supported boundary

The compiled path supports the six built-in v4 configurations: hydrostatic and nonhydrostatic `WVTransformConstantStratification`, `WVTransformHydrostatic`, `WVTransformBoussinesq`, `WVTransformStratifiedQG`, and `WVTransformBarotropicQG`, subject to each family's qualified operation set. Built-in MATLAB fields and supported primitive calls use the shared native kernels. Custom operations and forcing callbacks remain MATLAB orchestration; calls they make to supported primitives may dispatch to the compiled path. An explicitly requested compiled primitive fails with its documented error when unavailable and never silently falls back to MATLAB.

| Configuration | Qualified compiled coverage |
| --- | --- |
| Constant stratification, hydrostatic | F/G raw transforms and derivatives, horizontal Fourier and `diffX`/`diffY`, vertical calculus, wave-vortex projection, fields, and nonlinear flux |
| Constant stratification, nonhydrostatic | F/G raw transforms and derivatives, horizontal Fourier and `diffX`/`diffY`, vertical calculus, wave-vortex projection, fields, and nonlinear flux |
| Variable-stratification hydrostatic | F/G raw transforms and derivatives, horizontal Fourier and `diffX`/`diffY`, vertical calculus, wave-vortex projection, fields, and nonlinear flux |
| Variable-stratification Boussinesq | F/G raw transforms and derivatives, horizontal Fourier and `diffX`/`diffY`, vertical calculus, wave-vortex projection, fields, and nonlinear flux |
| Stratified QG | F/G raw transforms, horizontal Fourier and `diffX`/`diffY`, vertical calculus, QGPV projection, fields, and nonlinear flux |
| Barotropic QG | Horizontal Fourier and `diffX`/`diffY`, QGPV projection, fields, and nonlinear flux |

The native configuration and prepared modal values are immutable. A new configuration is rebuilt through reconstruction or a resolution factory; each outer evaluation copies the current coefficients once into a native snapshot and retains it until that evaluation ends. No MATLAB buffer pointer is retained between MEX calls. Backend selection is runtime-only and is not written to NetCDF. Ordinary NetCDF restoration selects MATLAB; request the compiled backend explicitly when restoring a compatible transform:

```matlab
wvt = WVTransform.waveVortexTransformFromFile("restart.nc",computationalBackend="compiled");
```

The compiled path may trade higher memory use for lower numerical-call runtime. The bridge and native provider identities are observable through the capability and metadata surfaces. See the [compiled-kernel contract](/developers-guide/compiled-kernel-contract.html) for implementation, ownership, and provider details.

## Reuse an evaluation

Model RHS and output events share compiled dependencies automatically. For several standalone requests from an unchanged state, keep the returned scope alive:

```matlab
scope = wvt.scopedEvaluation();
u = wvt.u;
v = wvt.v;
clear scope
```

Changing coefficients or time invalidates the active scope. Release it before evaluating the new state. `computationalBackendMetadata` reports producer counts, cache hits, state-copy bytes, storage, bridge version, and the build's source and binary identities.
