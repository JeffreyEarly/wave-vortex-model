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

State, masks, and fluxes use the canonical WV grid with shape `[Nj,Nkl]`; physical fields retain `[Nx,Ny,Nz]`. Storage is contiguous and column-major, so the zero-based C++ offset is

$$operatorname{offset}(j,i_{kl})=j+N_j i_{kl}.$$

This keeps the vertical dimension adjacent, matching the MATLAB representation and its efficient vertical matrix products. The compiled implementation may use other transient layouts internally, including Hermitian half spectra, but they never alter the public coefficient ordering.

Inputs are immutable. The caller allocates `Fp`, `Fm`, and `F0`, and these outputs may not overlap each other or the state. A steady-state kernel call will allocate no heap storage after the context has been prepared.

`WVComplex64` is a standard-layout pair of doubles. A future MEX adapter must verify that MATLAB's interleaved complex representation has the same size and alignment before creating zero-copy views.

## Immutable configuration and derived data

`WVTransformConstantStratificationConfiguration` contains the physical domain, grid sizes, retained vertical mode count, planetary parameters, hydrostatic selection, and antialias selection. The portable descriptor derives:

- canonical horizontal mode ordering and compact Fourier mappings;
- horizontal wavenumbers and the Coriolis frequency;
- the constant-stratification vertical grid, mode numbers, and equivalent depths;
- all projection, reconstruction, phase, and normalization coefficients used by the fused transforms.

Dense MATLAB DCT/DST or projection matrices are not imported. Constant-stratification modes are analytic and will be built inside C++. A future variable-stratification extension may accept eigenvalues and vertical structures from an external mode solver, but that is not part of this contract.

Contract version 4 normalizes immutable tables by their natural dimensions. Vertical-only factors such as `Fg`, `Gg`, their reciprocals, and vertical wavenumbers have shape `[Nj]`; horizontal magnitude and direction factors have shape `[Nkl]`; only coefficients that genuinely couple a vertical and horizontal mode retain `[Nj,Nkl]`. The pre-scaled experimental form also folds reconstruction and projection normalization into those coupled coefficients. This changes descriptor-table semantics without changing the canonical state, flux, or transform results.

## FFT-engine boundary

`WVFFTEngine` creates `WVFFTPlan` objects from an engine-neutral `WVFFTPlanSpecification`. Specifications identify horizontal r2c/c2r or vertical DCT-I/DST-I operations together with dimensions, batches, strides, alignment requirements, and destructive-input behavior.

FFT engines return their native unnormalized transforms. The WaveVortex kernel owns normalization, phase, modal coefficients, wavenumber multipliers, and Hermitian completion. No FFTW plan or library type crosses the interface.

This separation permits the MATLAB build to use MATLAB's bundled FFTW while a standalone program may use a native FFTW build or another compatible engine.

## Fused transform dataflow

The transform core uses one reusable batch-first Hermitian half-x arena with logical shape `[Nz,Nchannel,NxHalf,Ny]`. It never constructs the omitted half of the horizontal spectrum and does not retain a second WV-ordered vertical scratch array.

Forward projection batches the three hydrostatic fields or four nonhydrostatic fields in one horizontal r2c plan. DCT-I and DST-I then operate directly along the adjacent `Nz` dimension in that same half-spectrum arena. The gather to `[Nj,Nkl]` applies horizontal normalization, conjugation, modal projection, and phase while discarding unretained vertical and horizontal modes.

Inverse reconstruction performs modal algebra while scattering directly from `[Nj,Nkl]` into the half-spectrum arena. It completes only the Hermitian relationships on stored zero/Nyquist boundary planes, runs the batched vertical transforms in place, and reconstructs `U`, `V`, `W`, and `N` with one horizontal c2r plan.

The F- and G-grid derivative calls likewise produce value, x derivative, y derivative, and z derivative together. Horizontal wavenumber multipliers and the DCT/DST derivative-family change are applied before one batched inverse transform. The returned array has shape `[Nx,Ny,Nz,4]` in the order value, x, y, z.

The context owns fourteen immutable plans plus the bounded half-spectrum arena. Plan creation may allocate engine-owned memory, but repeated calls make no C++ heap allocation. The authoring FFTW implementation uses unaligned guru plans and reports the dynamically loaded library identity. FFTW is supplied by the embedding application and is not a dependency of the portable core.

## Thin MEX boundary

The authoring diagnostic MEX adapter has four responsibilities:

1. Validate MATLAB types, dimensions, complex layout, and non-aliasing.
2. Construct or retrieve one C++ context.
3. Pass non-owning views to the portable entry point.
4. Translate `WVKernelStatus` into a stable `WaveVortexModel:CompiledKernel:*` error.

It does not implement transforms, retain MATLAB model state, or duplicate the numerical algorithm. It is benchmark/test infrastructure, not a public compiled backend. Integration, forcing objects, persistence, observing systems, and user operations remain in MATLAB.

## Baseline

The authoring command

```matlab
addpath("Benchmarks")
results = runCompiledKernelBuiltinBaseline
```

runs the four `core-v1` constant-stratification cases and three fresh-process storage/RSS measurements. It records complete state-advanced `nonlinearFlux` timing, exact known storage, opaque MATLAB FFT storage, process RSS, source hashes, and the active builtin backend. The final kernel decision compares against this optimized builtin path, not against the retired fine-grained FFTW adapter.

The issue #49/#50 transform benchmark is separate from that final nonlinear-kernel decision:

```matlab
addpath("Benchmarks")
results = runCompiledKernelTransformBenchmark
```

It compares complete MATLAB and diagnostic-MEX calls for forward projection, inverse reconstruction, and the fused F/G derivative collections. It records raw samples, medians, exact errors, plan/scratch storage, source identities, and the loaded FFTW library. These component results are descriptive; issue #53 retains the complete `nonlinearFlux` readiness gate.
