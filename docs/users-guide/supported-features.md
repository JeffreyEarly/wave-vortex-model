---
layout: default
title: Capabilities and limitations
parent: User guide
nav_order: 3
has_toc: true
---

# Capabilities and limitations

WaveVortexModel provides five transform families together with model integration, forcing, observing systems, and NetCDF output. This page summarizes the documented public behavior and important limitations. Public MATLAB visibility alone does not make an implementation helper a recommended entry point.

## Transforms

| Transform | Description |
| --- | --- |
| `WVTransformConstantStratification` | Hydrostatic or nonhydrostatic flow with constant buoyancy frequency. |
| `WVTransformHydrostatic` | Hydrostatic flow with variable stratification. |
| `WVTransformBoussinesq` | Nonhydrostatic flow with variable stratification. |
| `WVTransformStratifiedQG` | Stratified quasigeostrophic flow. |
| `WVTransformBarotropicQG` | Equivalent-barotropic quasigeostrophic flow. |

The rotating transforms accept either hemisphere for `5 <= abs(latitude) <= 85`, including the endpoints. Horizontal grids may contain independently chosen positive even or odd grid counts. The built-in MATLAB FFT implementation is used by the documented transform constructors.

Mode/index mappings accept scalars and column vectors. Resolution conversion and explicit antialiasing preserve coefficients identified by common integer mode numbers and initialize newly introduced modes to zero. Energy and, where defined, enstrophy agree between spectral and spatial representations within the transform discretization tolerance.

## Interpolation and vertical calculus

Public field and particle interpolation accepts periodic `linear` and `spline` methods. Horizontal coordinates wrap periodically.

For three-dimensional transforms, `diffZF` and `diffZG` accept derivative orders 1 through 4 on `[Nx Ny Nz]` grids. `intZF` and `intZG` provide first antiderivatives on `[Nx Ny Nz]` grids and `[Nz N]` matrices. MATLAB argument validation rejects other orders and layouts.

`hasMeanPressureDifference` detects a resolved horizontally averaged pressure difference produced by the mean-density-anomaly component. Transforms without that component return `false`.

`summarizeDegreesOfFreedom` reports the spatial grid and mask-derived active spectral degrees of freedom. `WVTotalFlowComponent.solutionForModeAtIndex` orders primary components by `shortName` while preserving the local mode ordering within each component.

## Model integration

`WVModel` provides adaptive and fixed-step integration, tolerance and time-step configuration, segmented integration, model output, and restart. Call `setupIntegrator` to change time-stepping settings.

The `adaptive-cell` option is under development and does not have the validation coverage of fixed-step and adaptive integration. Low-level integrator mixins and `ode45_cell` are implementation machinery rather than model entry points.

## Forcing and closures

The supplied forcing and closure classes are:

- `WVNonlinearAdvection`
- `WVAdaptiveDamping`
- `WVAntialiasing`
- `WVHorizontalDamping`
- `WVVerticalDamping`
- `WVVerticalDiffusivity`
- `WVFixedAmplitudeForcing`
- `WVNarrowBandGeostrophicForcing`
- `WVBottomFrictionLinear`
- `WVBottomFrictionQuadratic`
- `WVBetaPlanePVAdvection`
- `WVPseudoTopographicWaveGeneration`

`WVThermalDamping` is under development and has more limited validation than the classes above. Custom forcing may be implemented through the documented `WVForcing` extension interface.

## Observing systems, output, and restart

`WVModel` supports Eulerian fields, wave-vortex coefficients, Lagrangian particles, moorings, and tracers through `WVEulerianFields`, `WVCoefficients`, `WVLagrangianParticles`, `WVMooring`, and `WVTracer`.

`WVModelOutputFile`, `WVModelOutputGroup`, and `WVModelOutputGroupEvenlySpaced` organize NetCDF output. Transform state, forcing, observing systems, output configuration, and model state can be restored from restart-capable files. File handles remain caller-owned where documented and should be closed explicitly.

## Extension interfaces and optional software

Custom operations and annotated variables use `WVOperation` and `WVVariableAnnotation`. Custom flow components use the documented `WVFlowComponent` interfaces.

Optimization Toolbox is optional. `WVNoMotionProfileOperation` uses `lsqnonlin` when it is available and otherwise uses `fminsearch` with an advisory warning.

WaveVortexModel uses MATLAB's builtin Fourier transforms. The experimental WaveVortex FFTW selector was retired after complete nonlinear-advection benchmarks did not justify its additional integration complexity. The reusable FFTWTransforms package remains independent of WaveVortexModel. The low-level barotropic FINUFFT path remains development machinery and is not selected through the documented interpolation options; FINUFFT is not a required package dependency.
