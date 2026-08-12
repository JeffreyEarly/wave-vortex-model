---
layout: default
title: Compiled kernel contract
parent: Developers guide
nav_order: 11
mathjax: true
---

# Compiled kernel contract

WaveVortexModel is developing a portable C++ numerical core for the constant-stratification nonlinear calculation. The initial contract deliberately contains no MATLAB, MEX, FFTW, or NetCDF types. MATLAB and a future standalone runtime will call the same numerical interface through separate adapters.

No compiled backend is currently exposed to model users. The optimized MATLAB implementation remains the production path and the performance baseline.

## Correspondence with MATLAB

Names are retained where the mathematical object is the same in both languages.

| MATLAB concept | C++ contract | Ownership |
|---|---|---|
| `WVTransformConstantStratification` construction parameters | `WVTransformConstantStratificationConfiguration` | Copied into the kernel descriptor |
| `Ap`, `Am`, `A0` at `t0` | `WVCoefficients` inside `WVState` | Read-only caller views |
| `t`, `t0` | `WVState.t`, `WVState.t0` | Values supplied for each call |
| `Fp`, `Fm`, `F0` | `WVFlux` | Preallocated caller views |
| `nonlinearFlux` | `WVTransformConstantStratificationKernel::nonlinearFlux` | Kernel operation |
| `transformUVEtaToWaveVortex` | `WVTransformConstantStratificationKernel::transformUVEtaToWaveVortex` | Caller-owned real input and coefficient outputs |
| `transformUVWEtaToWaveVortex` | `WVTransformConstantStratificationKernel::transformUVWEtaToWaveVortex` | Caller-owned real input and coefficient outputs |
| `transformWaveVortexToUVWEta` | `WVTransformConstantStratificationKernel::transformWaveVortexToUVWEta` | Caller-owned coefficients and real output |
| `transformToSpatialDomainWithFAllDerivatives` | Method with the same name | Caller-owned WV-grid inputs and `[Nx,Ny,Nz,4]` output |
| `transformToSpatialDomainWithGAllDerivatives` | Method with the same name | Caller-owned WV-grid inputs and `[Nx,Ny,Nz,4]` output |

The C++ name is allowed to differ when C++ ownership or lifecycle semantics need to be explicit. The kernel context is non-copyable, owns plans and bounded scratch, and does not own authoritative model state.

## Canonical coefficient layout

State and fluxes use the canonical WV grid with shape `[Nj,Nkl]`; physical fields retain `[Nx,Ny,Nz]`. Storage is contiguous and column-major, so the zero-based C++ offset is

$$operatorname{offset}(j,i_{kl})=j+N_j i_{kl}.$$

This keeps the vertical dimension adjacent, matching the MATLAB representation and its efficient vertical matrix products. The compiled implementation may use other transient layouts internally, including Hermitian half spectra, but they never alter the public coefficient ordering.

Inputs are immutable. The caller allocates `Fp`, `Fm`, and `F0`, and these outputs may not overlap each other or the state. A steady-state kernel call will allocate no array-sized storage after the context has been prepared.

`WVComplex64` is a standard-layout pair of doubles. A future MEX adapter must verify that MATLAB's interleaved complex representation has the same size and alignment before creating zero-copy views.

## Immutable configuration and derived data

`WVTransformConstantStratificationConfiguration` contains the physical domain, grid sizes, retained vertical mode count, planetary parameters, hydrostatic selection, and antialias selection. The portable descriptor derives:

- canonical horizontal mode ordering and compact Fourier mappings;
- horizontal wavenumbers and the Coriolis frequency;
- the constant-stratification vertical grid, mode numbers, and equivalent depths;
- all projection, reconstruction, phase, and normalization coefficients used by the fused transforms.

Dense MATLAB DCT/DST or projection matrices are not imported. Constant-stratification modes are analytic and will be built inside C++. A future variable-stratification extension may accept eigenvalues and vertical structures from an external mode solver, but that is not part of this contract.

Contract version 4 stores each immutable quantity at its natural dimensionality. Vertical-only quantities use `[Nj]`, horizontal-only quantities live with the `Nkl` Fourier-mode records, and only coefficients that genuinely couple vertical and horizontal modes use `[Nj,Nkl]`. Field-assembly and coefficient-projection factors are pre-scaled at construction, so the runtime loops do not repeat divisions or normalization products. Construction-only reciprocals and scale arrays are not retained.

## FFT-engine boundary

`WVFFTEngine` creates `WVFFTPlan` objects from an engine-neutral `WVFFTPlanSpecification`. Specifications identify horizontal r2c/c2r or vertical DCT-I/DST-I operations together with dimensions, batches, strides, alignment requirements, and destructive-input behavior.

FFT engines return their native unnormalized transforms. The WaveVortex kernel owns normalization, phase, constant-stratification coefficients, wavenumber multipliers, and Hermitian completion. No FFTW plan or library type crosses the interface.

This separation permits the MATLAB build to use MATLAB's bundled FFTW while a standalone program may use a native FFTW build or another compatible engine.

## Fused transform dataflow

The transform core uses one reusable batch-first Hermitian half-x arena with logical shape `[Nz,Nchannel,NxHalf,Ny]`. It never constructs the omitted half of the horizontal spectrum and does not retain a second WV-ordered vertical scratch array.

Forward projection batches the three hydrostatic fields or four nonhydrostatic fields in one horizontal r2c plan. DCT-I and DST-I then operate directly along the adjacent `Nz` dimension in that same half-spectrum arena. The gather to `[Nj,Nkl]` applies horizontal normalization, conjugation, field-to-WV coefficient projection, and phase while discarding unretained vertical and horizontal modes.

Inverse reconstruction performs WV-coefficient-to-field spectral assembly while scattering directly from `[Nj,Nkl]` into the half-spectrum arena. It completes only the Hermitian relationships on stored zero/Nyquist boundary planes, runs the batched vertical transforms in place, and reconstructs `U`, `V`, `W`, and `N` with one horizontal c2r plan.

The F- and G-grid derivative calls likewise produce value, x derivative, y derivative, and z derivative together. Horizontal wavenumber multipliers and the DCT/DST derivative-family change are applied before one batched inverse transform. The returned array has shape `[Nx,Ny,Nz,4]` in the order value, x, y, z.

The context owns seventeen immutable plans plus the bounded half-spectrum arena and rolling real-space scratch. Its known scratch bound is `4H+6R`, where `H` is the Hermitian half-spectrum size and `R` is the real-grid size. Plan creation may allocate engine-owned memory. Each coefficient stage uses two transient workers that join before any FFT execution, so coefficient work and FFTW threads never overlap. The native FFTW adapter uses unaligned guru plans and reports the dynamically loaded library identity. FFTW is supplied by the embedding application and is not a dependency of the portable core.

The scientific stages retain their MATLAB names even where their execution is fused:

| Scientific stage | MATLAB operation | C++ operation |
|---|---|---|
| WV coefficients to fields | `transformWaveVortexToUVWEta` | `transformWaveVortexToUVWEta` |
| F-family value and derivatives | `transformToSpatialDomainWithFAllDerivatives` | Method with the same name |
| G-family value and derivatives | `transformToSpatialDomainWithGAllDerivatives` | Method with the same name |
| Nonlinear products | ordinary `nonlinearFlux` product loop | internal rolling real-space loop |
| Fields to WV coefficients | `transformUVEtaToWaveVortex` or `transformUVWEtaToWaveVortex` | Methods with the same names |

## Thin MEX boundary

The internal MEX adapter has four responsibilities:

1. Validate MATLAB types, dimensions, complex layout, and non-aliasing.
2. Construct or retrieve one C++ context.
3. Pass non-owning views to the portable entry point.
4. Translate `WVKernelStatus` into a stable `WaveVortexModel:CompiledKernel:*` error.

It does not implement transforms, retain authoritative MATLAB model state, or duplicate the numerical algorithm. The adapter and core are internal infrastructure; no model constructor selects them yet. Public backend selection, forcing validation, persistence behavior, and user operations remain separate integration work.

## Source-only native provider

`WVCompiledBackend` is the developer-facing build and inspection surface:

```matlab
capabilities = WVCompiledBackend.capabilities();
capabilities = WVCompiledBackend.build();
```

`capabilities()` performs no download or compilation and returns structured unavailability on unsupported systems. `build()` is the only operation that may download and compile. It fetches the official FFTW 3.3.11 archive, verifies the pinned SHA-256 digest, builds the selected NEON/pthreads shared provider, stages the MEX module, validates its numerical and lifecycle contracts, and installs it transactionally beside the package root.

The initial provider supports Apple-silicon `maca64` with MATLAB R2025b or later. Its thread count is `min(18,maxNumCompThreads)`. Both FFTW libraries must resolve to the ignored local provider through `dladdr`; MATLAB-bundled FFTW and OpenMP runtimes are rejected. The deterministic hydrostatic and nonhydrostatic self-tests require relative error at most `1e-12`, contract version 4, seventeen plans, and balanced cleanup.

The repository distributes the core, adapter, and build sources only. The downloaded archive, extracted FFTW source, compiled libraries, build cache, and MEX module are ignored local products and are never exported as package payload.

## Integration boundary

The shared C++ core is intentionally usable by both a MATLAB/MEX preview and a future standalone runtime. It contains no MATLAB, MEX, NetCDF, FFTW, or Apple APIs. `WVFFTEngine` is the only transform boundary, and the native provider is one embedding-specific implementation. A future runtime can supply the same interface without carrying MATLAB ownership or capability machinery.

The currently integrated infrastructure does not add a `computationalBackend` option and does not change package version or dependencies. Historical benchmark harnesses, provider sweeps, rejected schedules, and canonical engineering artifacts remain outside the production tree.
