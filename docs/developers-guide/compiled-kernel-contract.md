---
layout: default
title: Compiled kernel contract
parent: Developers guide
nav_order: 11
mathjax: true
---

# Compiled kernel contract

WaveVortexModel provides portable C++ numerical cores for the constant-stratification and equivalent-barotropic quasigeostrophic calculations. The contract deliberately contains no MATLAB, MEX, FFTW, or NetCDF types. Embeddings supply transform providers and ownership through separate adapters.

The optimized MATLAB implementation remains the default and the public performance baseline. Constant-stratification transforms may explicitly select the compiled preview after locally building its native provider. The Barotropic QG implementation is a focused source-level numerical kernel and integration system; it is not a new MATLAB backend selector or a complete standalone `WVModel` persistence path.

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

The Barotropic QG correspondence is deliberately compact:

| MATLAB concept | C++ contract | Ownership |
|---|---|---|
| `WVTransformBarotropicQG` geometry and physical parameters | `WVTransformBarotropicQGConfiguration` | Copied into the transform descriptor |
| compact `A0` in MATLAB `kl` order | `WVComplexConstView` with shape `[1,Nkl]` | Read-only caller view |
| `qgpv` normalization and projection | `transformA0ToQGPV` and `transformQGPVToA0` | Caller-owned spatial or compact output |
| `u`, `v`, `eta`, `pi`, `psi`, `qgpv`, `zeta_z`, and `ssh` | `transformA0ToField` | Caller-owned `[Nx,Ny]` output |
| field, x derivative, and y derivative | `transformA0ToFieldWithDerivatives` | Caller-owned `[Nx,Ny,1,3]` output |
| ordinary PV advection | `WVTransformBarotropicQGKernel::nonlinearFlux` | Caller-owned compact `F0` |
| spectral and spatial energy and enstrophy | Matching total-invariant operations | Scalar caller outputs |

The C++ name is allowed to differ when C++ ownership or lifecycle semantics need to be explicit. The kernel context is non-copyable, owns plans and bounded scratch, and does not own authoritative model state.

## Canonical coefficient layout

State and fluxes use the canonical WV grid with shape `[Nj,Nkl]`; physical fields retain `[Nx,Ny,Nz]`. Storage is contiguous and column-major, so the zero-based C++ offset is

$$operatorname{offset}(j,i_{kl})=j+N_j i_{kl}.$$

This keeps the vertical dimension adjacent, matching the MATLAB representation and its efficient vertical matrix products. The compiled implementation may use other transient layouts internally, including Hermitian half spectra, but they never alter the public coefficient ordering.

Barotropic QG uses the MATLAB `kl` ordering directly with shape `[1,Nkl]`. Its one `A0` family is normalized as QGPV, excludes the zero-horizontal-wavenumber geostrophic mode, and contains no `Ap` or `Am` storage. The omitted conjugates are reconstructed only in bounded half-spectrum scratch; no full Hermitian spectrum is retained.

Inputs are immutable. The caller allocates `Fp`, `Fm`, and `F0`, and these outputs may not overlap each other or the state. A steady-state kernel call will allocate no array-sized storage after the context has been prepared.

`WVComplex64` is a standard-layout pair of doubles. The MEX adapter verifies that MATLAB's interleaved complex representation has the same size and alignment before creating zero-copy views.

## Immutable configuration and derived data

`WVTransformConstantStratificationConfiguration` contains the physical domain, grid sizes, retained vertical mode count, planetary parameters, hydrostatic selection, and antialias selection. The portable descriptor derives:

- canonical horizontal mode ordering and compact Fourier mappings;
- horizontal wavenumbers and the Coriolis frequency;
- the constant-stratification vertical grid, mode numbers, and equivalent depths;
- all projection, reconstruction, phase, and normalization coefficients used by the fused transforms.

Dense MATLAB DCT/DST or projection matrices are not imported. Constant-stratification modes are analytic and will be built inside C++. A future variable-stratification extension may accept eigenvalues and vertical structures from an external mode solver, but that is not part of this contract.

`WVTransformBarotropicQGConfiguration` contains `Nx`, `Ny`, `Lx`, `Ly`, equivalent depth `h`, mode `j`, gravity, planetary radius, rotation rate, latitude, and the transform-level antialias flag. Its descriptor reproduces MATLAB's radial-`Kh`, then `K`, then `L` `kl` ordering; odd/even and nonsquare Nyquist rules; optional radial two-thirds mask; compact half-spectrum mappings; Coriolis and deformation scales; and all `A0` reconstruction, projection, energy, and enstrophy factors. Both `j=0` and `j=1` use the same compact contract.

Compiled-kernel contract version 4 stores each immutable quantity at its natural dimensionality. Vertical-only quantities use `[Nj]`, horizontal-only quantities live with the `Nkl` Fourier-mode records, and only coefficients that genuinely couple vertical and horizontal modes use `[Nj,Nkl]`. Field-assembly and coefficient-projection factors are pre-scaled at construction, so the runtime loops do not repeat divisions or normalization products. Construction-only reciprocals and scale arrays are not retained. This data contract is independent of the `wave-vortex-portable-source-api-v1` C++ compilation contract and of every observer, forcing, schedule, observation-schema, and run-request version; none of those versions is inferred from kernel version 4.

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

## Barotropic QG dataflow

The Barotropic QG context owns three plans: one scalar horizontal forward plan, one scalar inverse plan, and one four-channel inverse plan. Its exact bounded scratch is `4H+5R`, where `H=(floor(Nx/2)+1)Ny` complex values and `R=NxNy` real values. The four-channel inverse reconstructs `u`, `v`, `qgpv_x`, and `qgpv_y`; the pointwise stage computes `-(u*qgpv_x+v*qgpv_y)`; and the scalar forward plan returns compact `F0`. The same masked compact mappings implement the transform-level antialias path. The reference direct-DFT engine provides portable correctness and non-Apple development, while the pinned native FFTW adapter supplies the optimized Apple-silicon path.

Construction and failure tests account for descriptor, engine, plan, management, compact state, and scratch bytes separately. Partial plan creation destroys every completed plan. Native lifecycle tests require three live plans only while the kernel exists, balanced create/destroy totals afterward, and zero outstanding planning-surrogate bytes. Deterministic MATLAB/C++ fixtures cover odd, even, and nonsquare grids, both `j` values, both antialias settings, coefficient and half-spectrum mappings, fields, derivatives, projections, invariants, linear evolution, and nonlinear PV tendencies with relative tolerance `1e-12`.

## Thin MEX boundary

The MEX adapter has four responsibilities:

1. Validate MATLAB types, dimensions, complex layout, and non-aliasing.
2. Construct or retrieve one C++ context.
3. Pass non-owning views to the portable entry point.
4. Translate `WVKernelStatus` into a stable `WaveVortexModel:CompiledKernel:*` error.

It does not implement transforms, retain authoritative MATLAB model state, or duplicate the numerical algorithm. `WVCompiledConstantStratificationBackend` owns one MEX handle and exposes the core to `WVTransformConstantStratification` without moving numerical formulas into MATLAB.

## Source-only native provider

`WVCompiledBackend` is the developer-facing build and inspection surface:

```matlab
capabilities = WVCompiledBackend.capabilities();
capabilities = WVCompiledBackend.build();
```

`capabilities()` performs no download or compilation and returns structured unavailability on unsupported systems. `build()` is the only operation that may download and compile. It fetches the official FFTW 3.3.11 archive, verifies the pinned SHA-256 digest, builds the selected NEON/pthreads shared provider, stages the MEX module, validates its numerical and lifecycle contracts, and installs it transactionally beside the package root.

The initial provider supports Apple-silicon `maca64` with MATLAB R2025b or later. Its thread count is `min(18,maxNumCompThreads)`. Both FFTW libraries must resolve to the ignored local provider through `dladdr`; MATLAB-bundled FFTW and OpenMP runtimes are rejected. The deterministic hydrostatic and nonhydrostatic self-tests require relative error at most `1e-12`, contract version 4, seventeen plans, and balanced cleanup.

The repository distributes the core, adapter, and build sources only. The downloaded archive, extracted FFTW source, compiled libraries, build cache, and MEX module are ignored local products and are never exported as package payload.

## MATLAB preview boundary

After building native support explicitly, select the preview with:

```matlab
WVCompiledBackend.build();
wvt = WVTransformConstantStratification(Lxyz,Nxyz,computationalBackend="compiled");
```

The default `computationalBackend="matlab"` path does not query or build native support. An explicit compiled request validates the provider, loaded libraries, contract, and numerical self-tests before creating a kernel. Failure is reported immediately and never falls back to MATLAB.

The preview implements ordinary `nonlinearFlux` only when the forcing registry contains exactly the default `WVNonlinearAdvection`. The transform checks that invariant on every call, so later forcing changes cannot be silently omitted. Transform-level antialiasing remains part of the kernel configuration; conversion to a separate `WVAntialiasing` forcing is unsupported.

Backend selection is runtime-only. Ordinary NetCDF restoration selects MATLAB, while `WVTransform.waveVortexTransformFromFile(path,computationalBackend="compiled")` is an explicit override for constant-stratification files. Provider paths, plans, handles, and backend metadata are never persisted.

`computationalBackendMetadata` reports the requested and active implementation, native identities, contract, thread count, storage estimates, and live kernel metrics. The compiled preview is known to use more memory than MATLAB; explicit selection accepts that documented limitation.

## Shared-runtime boundary

The shared C++ core is used by both the MATLAB/MEX preview and the standalone portable runtime. It contains no MATLAB, MEX, NetCDF, FFTW, or Apple APIs. `WVFFTEngine` is the only transform boundary, and each embedding supplies its provider without carrying another embedding's ownership or capability machinery.

The preview does not change package version or dependencies. Historical benchmark harnesses, provider sweeps, rejected schedules, and canonical engineering artifacts remain outside the production tree.
