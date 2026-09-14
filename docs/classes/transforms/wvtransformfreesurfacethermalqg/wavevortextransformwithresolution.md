---
layout: default
title: waveVortexTransformWithResolution
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 253
mathjax: true
---

#  waveVortexTransformWithResolution

Create the same transform family at a new resolution.


---

## Declaration
```matlab
 wvtNew = waveVortexTransformWithResolution(resolution)
```
## Parameters
+ `Nxyz`  target horizontal Fourier sizes and vertical sample count
+ `options.thermalModeCount`  target complete thermal dimension
+ `options.mdaModeCount`  target independently retained mean dimension

## Returns
+ `other`  new transform with transferred state, clocks and forcing
+ `assessment`  physical discarded-content and projection residuals

## Discussion
Create the same transform family at a new resolution.

The returned transform preserves the physical domain, configuration, time, compatible forcing, and resolved state while converting coefficients to the requested grid size.

```matlab
wvtFine = wvt.waveVortexTransformWithResolution([16 12 9]);
```
