---
layout: default
title: Portable checkpoint profile
parent: Developers guide
nav_order: 12
---

# Portable checkpoint profile

The `wave-vortex-4x-v1` profile is the structurally validated subset of existing WaveVortexModel 4.x NetCDF files consumed by the portable constant-stratification runtime. It does not define another file layout. MATLAB remains the authoritative writer, and the C++ `WaveVortexCheckpoint` library reads the same groups, dimensions, variables, and attributes used by `WVTransform.waveVortexTransformFromFile`.

The profile is deliberately narrower than the general [`NetCDFFile`](https://github.com/JeffreyEarly/netcdf) and `CAAnnotatedClass` conventions. It supports the numerical configuration, canonical wave-vortex state, and forcing type headers needed by a portable constant-stratification runtime. It does not reconstruct arbitrary annotated classes, MATLAB function handles, observing systems, or unrelated variables.

## Root configuration

The root group must identify `WVTransformConstantStratification` through `WVTransform`, `AnnotatedClass`, or both. When both are present they must agree. `model_version` must have major version 4; compatible minor and patch versions are accepted based on their actual structure.

| Stored value | NetCDF representation | C++ destination |
|---|---|---|
| `x`, `y`, `z` | Nonempty, strictly increasing double coordinate variables | `Nx`, `Ny`, `Nz` from their lengths |
| `Lx`, `Ly`, `Lz` | Finite positive scalar doubles | Domain lengths |
| `N0`, `g`, `rho0` | Finite positive scalar doubles | Stratification and reference parameters |
| `planetaryRadius`, `rotationRate` | Finite positive scalar doubles | Planetary parameters |
| `latitude` | Finite scalar double in `[-90,90]` | Central latitude |
| `isHydrostatic`, `shouldAntialias` | Scalar byte logicals containing zero or one | Runtime switches |
| `t0` | Finite scalar double | Reference time for `Ap`, `Am`, and `A0` |

The reader constructs `WVTransformConstantStratificationConfiguration` from these values. The portable kernel then rebuilds Fourier ordering, half-spectrum mappings, vertical modes, modal coefficients, antialias selection, plans, and scratch. Derived runtime data is never part of the checkpoint contract.

## State discovery

The reader recursively searches for a single group containing all six component variables `Ap_real`, `Ap_imag`, `Am_real`, `Am_imag`, `A0_real`, and `A0_imag`, together with `t`. This supports both existing forms:

- transform checkpoints with scalar state in the root group;
- model output with a time series in a nested group such as `/wave-vortex`.

Zero or multiple complete state groups are errors. A group containing only part of a complex coefficient set is also an error rather than an invitation to infer missing state.

Scalar-state coefficient variables have NetCDF dimensions `[kl,j]`. Time-series variables have `[t,kl,j]`. A time-series read selects the final record by default or an explicit zero-based record index. Because the NetCDF C order makes `j` the adjacent dimension, one selected slab already has the canonical WaveVortex column-major layout `[Nj,Nkl]`:

$$\operatorname{offset}(j,i_{kl}) = j + N_j i_{kl}.$$

No transpose or full-spectrum expansion is required. The reader combines the real and imaginary component arrays into owned `WVComplex64` coefficient storage, then verifies that a descriptor rebuilt from the root configuration produces the stored `Nj` and `Nkl`.

## Complex encoding

Each logical complex variable is stored as a pair of double variables with `_real` and `_imag` suffixes. Both components must have identical dimensions and the established marker attributes:

| Component | `isComplex` | `isRealPart` | `isImaginaryPart` |
|---|---:|---:|---:|
| `_real` | 1 | 1 | 0 |
| `_imag` | 1 | 0 | 1 |

This is the existing WaveVortexModel/NetCDF convention, not an opaque MATLAB serialization.

## Forcing headers

The profile records forcing identity without interpreting forcing parameters. A singleton forcing may be represented directly by `/forcing` with an `AnnotatedClass` attribute. Multiple forcing records appear as `/forcing/forcing-1`, `/forcing/forcing-2`, and so on. The reader returns their one-based order, group path, and `AnnotatedClass` tag.

The portable forcing capability matrix maps those existing tags and their numeric metadata to C++ implementations separately. Unknown forcing is rejected before execution; it is never silently omitted.

## C++ boundary

`WaveVortexCheckpoint` is a separate C++ library over the NetCDF C API. It depends on `WaveVortexKernel`, but the numerical kernel has no NetCDF, MATLAB, or MEX dependency. The reader owns file handles through a move-only RAII wrapper and reports structured status codes for missing metadata, incompatible types or shapes, unsupported model records, invalid state selection, and NetCDF failures.

Issue #111 provides read-only compatibility and validation. Compatible checkpoint creation, appending, and restart continuation remain part of the standalone runtime checkpoint work.
