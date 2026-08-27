---
layout: default
title: Compiled MATLAB backend preview
parent: Compiled execution
nav_order: 1
permalink: /users-guide/compiled-preview.html
---

# Compiled MATLAB backend preview

The compiled MATLAB backend is a source-only preview of the constant-stratification `nonlinearFlux` calculation. It runs inside MATLAB through MEX; `WVModel`, integration, forcing ownership, observers, and NetCDF output remain MATLAB operations.

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

The preview supports hydrostatic and nonhydrostatic `WVTransformConstantStratification` with transform-level antialiasing and exactly the default `WVNonlinearAdvection` forcing. Additional, removed, or replaced forcing is rejected. Other transform families, full-model integration in C++, and standalone persistence are not part of this preview.

Backend selection is runtime-only. Ordinary NetCDF restoration selects MATLAB. Request the compiled backend explicitly when restoring a compatible transform:

```matlab
wvt = WVTransform.waveVortexTransformFromFile("restart.nc",computationalBackend="compiled");
```

The preview may trade higher memory use for lower integration runtime. The accepted matched measurements report integration runtime and total peak process memory on the [Benchmarks](/benchmarks.html) page. See the [compiled-kernel contract](/developers-guide/compiled-kernel-contract.html) for implementation, ownership, and provider details.
