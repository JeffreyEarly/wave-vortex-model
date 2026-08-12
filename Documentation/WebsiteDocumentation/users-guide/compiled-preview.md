---
layout: default
title: Compiled constant-stratification preview
parent: User guide
nav_order: 4
---

# Compiled constant-stratification preview

WaveVortexModel includes a source-only preview of a compiled constant-stratification `nonlinearFlux` implementation. MATLAB remains the default. The preview is intended for users who want the measured speed improvement and can accept its currently higher memory use and narrow forcing contract.

## Build and inspect native support

The repository distributes C++ source but no FFTW library or MEX binary. On Apple silicon with MATLAB R2025b or later, build the pinned native provider explicitly:

```matlab
capabilities = WVCompiledBackend.capabilities();
if ~capabilities.isAvailable
    capabilities = WVCompiledBackend.build();
end
```

`capabilities()` never downloads or compiles. `build()` downloads the official FFTW 3.3.11 archive, verifies its checksum, and builds ignored local products. Review `capabilities.failure` if support remains unavailable.

## Select the preview

```matlab
wvt = WVTransformConstantStratification([15e3 15e3 1300],[256 256 65],computationalBackend="compiled");

metadata = wvt.computationalBackendMetadata;
[Fp,Fm,F0] = wvt.nonlinearFlux();
```

Successful construction means the native provider, loaded FFTW libraries, numerical self-tests, and compiled-kernel contract were validated. The implementation never silently falls back after an explicit request.

The preview supports hydrostatic and nonhydrostatic constant stratification with exactly the default `WVNonlinearAdvection` forcing. Additional, removed, or replaced forcing causes `nonlinearFlux` to fail clearly. Transform-level antialiasing is supported; the separate explicit-antialias forcing workflow is not.

## Persistence and cleanup

Backend selection is runtime-only and is not written to NetCDF. Ordinary restoration uses MATLAB:

```matlab
wvt = WVTransform.waveVortexTransformFromFile("restart.nc");
```

Request the compiled preview again explicitly when restoring a compatible constant-stratification file:

```matlab
wvt = WVTransform.waveVortexTransformFromFile("restart.nc",computationalBackend="compiled");
```

Deleting the transform releases its kernel, FFT plans, and MEX lock. `computationalBackendMetadata` reports bounded application-owned storage while FFTW plan allocations remain opaque. Consult the [Benchmarks](/benchmarks.html) page for measured runtime and memory together.
