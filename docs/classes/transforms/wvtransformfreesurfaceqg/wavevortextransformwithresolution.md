---
layout: default
title: waveVortexTransformWithResolution
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 248
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
+ `resolution`  positive integer spatial grid counts for the target transform

## Returns
+ `wvtNew`  transform of the same family at `resolution`

## Discussion
Create the same transform family at a new resolution.

The returned transform preserves the physical domain, configuration, time, compatible forcing, and resolved state while converting coefficients to the requested grid size.

```matlab
wvtFine = wvt.waveVortexTransformWithResolution([16 12 9]);
```
