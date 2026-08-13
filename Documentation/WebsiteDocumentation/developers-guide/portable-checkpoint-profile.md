---
layout: default
title: Portable checkpoint profile
parent: Developers guide
nav_order: 12
---

# Portable checkpoint profile

The `wave-vortex-4x-v1` profile is the structurally validated subset of existing WaveVortexModel 4.x NetCDF files consumed and produced by the portable constant-stratification runtime. It does not define another file layout. MATLAB and the C++ checkpoint library use the same groups, dimensions, variables, and attributes consumed by `WVTransform.waveVortexTransformFromFile`.

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

The reader constructs `WVTransformConstantStratificationConfiguration` from these values. The portable kernel then rebuilds Fourier ordering, half-spectrum mappings, vertical modes, WV reconstruction and projection coefficients, antialias selection, plans, and scratch. Derived runtime data is never part of the checkpoint contract.

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

`WaveVortexCheckpoint` is a separate C++ library over the NetCDF C API. It depends on `WaveVortexKernel`, but the numerical kernel has no NetCDF, MATLAB, or MEX dependency. The checkpoint layer owns file handles through move-only RAII wrappers and reports structured status codes for missing metadata, incompatible types or shapes, unsupported model records, invalid state selection, NetCDF failures, write failures, and commit failures.

## Compatible checkpoint writing

`WVCheckpointWriter` writes one root-level scalar checkpoint. It reconstructs the standard `x`, `y`, `z`, `j`, and `kl` coordinates from the validated constant-stratification configuration and writes canonical `[Nj,Nkl]` coefficient memory directly as NetCDF `[kl,j]` real/imaginary pairs. A singleton forcing is stored on `/forcing`; multiple records are restored to one-based source order as `/forcing/forcing-N`. Fixed-amplitude indices are converted from zero-based C++ offsets to the existing one-based NetCDF representation.

The writer accepts only canonical `wave-vortex-forcing-v1` records. It rejects unsupported forcing and any stage, priority, name, ordinal, shape, or payload that would reload with different semantics. It writes immutable forcing source data but not `deltaT`, FFT plans, mappings, antialias selections, derived operators, responses, caches, or scratch.

Output replacement is transactional. The writer validates the in-memory record, writes and synchronizes a uniquely named temporary file beside the destination, closes it, and reads it through `WVCheckpointReader`. Only a structurally valid temporary checkpoint that reproduces the requested state is atomically committed. Failure leaves an existing destination byte-for-byte unchanged and removes the temporary file.

Writer v1 does not append records and does not create a time-series group. Existing scalar and nested time-series files remain valid reader inputs; a selected time-series record may be emitted as a standalone scalar restart.

## Frozen forcing execution

`WVConstantStratificationForcingEngine` accepts only a validated `wave-vortex-forcing-v1` schedule. Construction sorts records by stage, priority, and stable source order, validates every numeric payload, and rebuilds immutable derived operators. Evaluation does not discover or dynamically dispatch MATLAB objects.

Runtime v1 implements `WVNonlinearAdvection`, `WVAdaptiveDamping`, `WVFixedAmplitudeForcing`, `WVBottomFrictionQuadratic`, `WVPseudoTopographicWaveGeneration`, and `WVBetaPlanePVAdvection`. Transform-level antialiasing remains the `shouldAntialias` configuration value. Unsupported supplied forcing and custom subclasses fail before integration; they are never silently omitted.

Spatial forcing is reconstructed and projected through the shared constant-stratification kernel. Spectral forcing operates directly on canonical `[Nj,Nkl]` coefficients. Fixed-amplitude forcing zeros its selected tendencies and separately restores its prescribed coefficients after restart, before each integration stage, and after each completed step.

## Fixed-step integration

`WVFixedStepRK4` implements the classical four-stage Runge--Kutta method with deterministic stage order. The stored state remains the three canonical coefficient arrays `Ap`, `Am`, and `A0`, together with `t` and the coefficient reference time `t0`. For a requested final time that is not an integer number of steps away, the integrator takes one shorter final step.

Let \(M=N_jN_{kl}\). The integrator retains one three-component stage state, one three-component stage tendency, and one three-component weighted accumulator. Its exact workspace is therefore

$$9M\operatorname{sizeof}(\texttt{WVComplex64}).$$

No previous-stage history is persisted. On restart, the checkpoint state is loaded, fixed amplitudes are restored, forcing-derived arrays and FFT plans are rebuilt, and RK4 continues from the stored time. This matches WaveVortexModel's persistence boundary: state is persisted; execution machinery is derived.

## Verification boundary

The portable contract tests compare every supported forcing and mixed hydrostatic/nonhydrostatic schedules directly with MATLAB at relative infinity error at most \(10^{-12}\). A short mixed-forcing RK4 trajectory is independently advanced in MATLAB and C++, including a partial final step and stage-wise fixed-amplitude restoration. The test fixtures also use nondefault gravity, density, and planetary values so the C++ descriptor reproduces established MATLAB normalization conventions rather than silently substituting its own.

Issue #111 established read compatibility and validation. Issue #115 adds compatible scalar checkpoint creation and deterministic restart continuation. Appending to a time-series remains outside runtime v1.

## Standalone runner boundary

`wave-vortex-run` is a thin executable over `WaveVortexPortableRuntime`, the shared constant-stratification kernel, and an explicitly selected `WVFFTEngine`. Its execution order is:

1. inspect checkpoint structure and decode the frozen forcing schedule;
2. validate every forcing record and requested endpoint;
3. load canonical `Ap`, `Am`, and `A0` storage;
4. construct the selected FFT engine, forcing engine, and RK4 workspace;
5. rebuild derived state after restart and integrate;
6. transactionally write a scalar restart checkpoint.

Inspection validates coefficient metadata and shape without allocating the three state arrays. A pseudo-topographic record necessarily loads its immutable two-dimensional height field during forcing validation, but no state-sized execution buffer is created until the checkpoint passes preflight.

The optimized executable accepts only the pinned native FFTW provider and reports its version, base and thread-library paths, thread count, 17-plan kernel contract, and no-fallback status. The portable reference provider is available only when selected explicitly and uses one thread. Provider selection is never automatic.

The JSON execution report separates inspection, reading, construction, restart preparation, integration, and writing. The readiness benchmark compares only the same eight fixed RK4 steps in the standalone process and the public compiled MATLAB preview. External RSS sampling uses the retained post-construction state as its baseline; FFTW plan-owned allocations remain opaque while all known descriptor, scratch, forcing, integrator, and checkpoint-state bytes are reported explicitly.
