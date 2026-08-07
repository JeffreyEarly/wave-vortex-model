---
layout: default
title: Supported features
parent: Users guide
nav_order: 3
has_toc: true
---

# Supported features

This page defines the target support contract for WaveVortexModel 4.2.1 and the remainder of the 4.2.x release line. It does not imply that every behavior in the released 4.2.0 package already conforms to this contract. Known gaps are listed below and are assigned to the linked stabilization issues.

Support applies to documented behavior through the public `WVTransform` and `WVModel` interfaces. A MATLAB class or method being publicly visible does not by itself make that interface supported.

## Status definitions

| Status | Meaning |
| --- | --- |
| Stable | Compatibility is promised throughout 4.2.x. A regression is a v4.2.1 release blocker. |
| Experimental | The feature is available, but its API or numerical behavior may change with notice. |
| Deprecated | The feature is retained in 4.2.x for migration and may be removed in the next major release. |
| Internal | The feature has no compatibility promise and must not be treated as a supported public API. |

No feature is assigned to Deprecated in the v4.2.1 target contract.

## Transforms and numerical services

| Feature | Status | Contract |
| --- | --- | --- |
| `WVTransformConstantStratification` | Stable | Hydrostatic and nonhydrostatic modes are supported. |
| `WVTransformHydrostatic` | Stable | The hydrostatic, variable-stratification transform is supported. |
| `WVTransformBoussinesq` | Stable | The nonhydrostatic, variable-stratification transform is supported. |
| `WVTransformStratifiedQG` | Stable | The stratified quasigeostrophic transform is supported. |
| `WVTransformBarotropicQG` | Stable | The equivalent-barotropic quasigeostrophic transform is supported. |
| Latitude | Stable | Supported transforms accept both hemispheres for `5 <= abs(latitude) <= 85`, including the endpoints. |
| MATLAB builtin FFT implementation | Stable | This is the supported Fourier-transform backend. |
| FFTW and `RealToComplexTransform` integration | Internal | These backend remnants are not selectable through a supported transform contract. |
| Periodic `linear` and `spline` interpolation | Stable | These are the only interpolation methods exposed by the supported public interpolation contract. |
| Vertical calculus for stable 3-D transforms | Stable | `diffZF` and `diffZG` support orders 1 through 4 on `[Nx Ny Nz]` grids. `intZF` and `intZG` support first antiderivatives on `[Nx Ny Nz]` grids and `[Nz N]` matrices. Unsupported orders and layouts are rejected through ordinary MATLAB argument validation. |
| `exact` and `finufft` interpolation | Internal | These implementation paths and option values must not appear in public option lists or user documentation. |
| `WVOffGridTransform`, external-wave behavior, and off-grid pressure | Internal | These incomplete remnants have no 4.2.x compatibility promise. |

## Integration

| Feature | Status | Contract |
| --- | --- | --- |
| Adaptive integration through `WVModel` | Stable | The public model facade, tolerance handling, output, and restart behavior are supported. |
| Fixed-step integration through `WVModel` | Stable | The public model facade, time-step selection, output, and restart behavior are supported. |
| `adaptive-cell` integration | Experimental | The option is available for evaluation but is not yet covered by a stable numerical or compatibility promise. |
| Integrator mixins and `ode45_cell` | Internal | Low-level integrator implementations are not supported entry points. |

## Forcing

Custom forcing through the documented `WVForcing` extension surface is Stable. The supplied forcing classes have the following status.

| Forcing class | Status |
| --- | --- |
| `WVNonlinearAdvection` | Stable |
| `WVAdaptiveDamping` | Stable |
| `WVAntialiasing` | Stable |
| `WVHorizontalDamping` | Stable |
| `WVVerticalDamping` | Stable |
| `WVVerticalDiffusivity` | Stable |
| `WVFixedAmplitudeForcing` | Stable |
| `WVBottomFrictionLinear` | Stable |
| `WVBottomFrictionQuadratic` | Stable |
| `WVBetaPlanePVAdvection` | Stable |
| `WVPseudoTopographicWaveGeneration` | Stable |
| `WVThermalDamping` | Experimental |
| `WVAdaptiveDiffusivity` | Internal |
| `WVAdaptiveViscosity` | Internal |
| `WVMeanFlowForcing` | Internal |
| `WVSpectralVanishingViscosity` | Internal |

The Internal forcing classes currently reside under `Forcing/Experimental`; their directory name does not override their status in this contract.

## Observing systems, output, and persistence

| Feature | Status | Contract |
| --- | --- | --- |
| `WVObservingSystem` | Stable | The supplied base class and documented custom observing-system extension surface are supported. |
| `WVEulerianFields` | Stable | Eulerian field observation is supported. |
| `WVCoefficients` | Stable | Wave-vortex coefficient observation and integration are supported. |
| `WVLagrangianParticles` | Stable | Lagrangian particle observation and integration are supported. |
| `WVMooring` | Stable | Mooring observation is supported. |
| `WVTracer` | Stable | Tracer observation and integration are supported. |
| `WVModelOutputFile` | Stable | Model output through supported NetCDF files is supported. |
| `WVModelOutputGroup` | Stable | Custom output grouping through the documented base interface is supported. |
| `WVModelOutputGroupEvenlySpaced` | Stable | Evenly spaced output grouping is supported. |
| NetCDF round trips and model restart | Stable | Supported transforms, forcing, observing systems, output configuration, and model state must round-trip and release their file handles. |

## Extension points and optional tooling

| Feature | Status | Contract |
| --- | --- | --- |
| `WVOperation` and `WVVariableAnnotation` extension surfaces | Stable | Documented custom operations and annotations are supported. |
| `WVFlowComponent` extension surface | Stable | Documented custom flow components are supported. |
| `WVNoMotionProfileOperation` solver selection | Stable | `lsqnonlin` is used when Optimization Toolbox is available; otherwise the warning-producing `fminsearch` fallback is supported. Optimization Toolbox remains optional. |
| Low-level `Adapative` and `mustBeDoulbyPeriodicFPlane` spellings | Internal | These names may be corrected without compatibility wrappers; the stable `WVModel` facade must remain unchanged. |

## Stable target contracts pending implementation

The following contracts are part of the v4.2.1 target even though their 4.2.0 implementations are incomplete.

| Interface | v4.2.1 target |
| --- | --- |
| `hasMeanPressureDifference` | Return the documented result instead of a placeholder error. |
| `WVTotalFlowComponent.solutionForModeAtIndex` | Return the documented total-flow solution instead of a placeholder error. |
| `summarizeDegreesOfFreedom` | Provide a general implementation for the stable transform surface. |

## Known 4.2.0 gaps and follow-up work

- [WVM-421-04: Restore a deterministic green test baseline](https://github.com/JeffreyEarly/wave-vortex-model/issues/11) will enforce the supported latitude range and reconcile the existing latitude tests.
- [WVM-421-06: Resolve exact interpolation and placeholder public-method contracts](https://github.com/JeffreyEarly/wave-vortex-model/issues/13) will implement the stable derivative, integral, pressure, modal-solution, and summary contracts and remove internal interpolation choices from public-facing option lists.
- [WVM-421-07: Add core transform invariant coverage](https://github.com/JeffreyEarly/wave-vortex-model/issues/14) will add representative and exhaustive coverage for every stable transform.
- [WVM-421-08: Add model, forcing, observing, output, and persistence coverage](https://github.com/JeffreyEarly/wave-vortex-model/issues/15) will cover the stable subsystem contracts and evaluate the experimental integration path separately.
- [WVM-421-09: Resolve correctness-related analyzer findings and legacy package artifacts](https://github.com/JeffreyEarly/wave-vortex-model/issues/16) will quarantine or remove internal remnants and correct internal misspellings without changing the stable model facade.

New scientific capabilities, new transform families, and broad refactoring are outside the v4.2.1 stabilization release.
