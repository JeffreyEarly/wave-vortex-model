---
layout: default
title: waveVortexTransformWithResolution
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 258
mathjax: true
---

#  waveVortexTransformWithResolution

Construct a qualified target and transfer matching resolved QG content.


---

## Declaration
```matlab
 [other,assessment] = waveVortexTransformWithResolution(Nxyz,options)
```
## Parameters
+ `Nxyz`  target horizontal Fourier sizes and vertical sample count
+ `options.apvModeCount`  target APV prefix count; default source count
+ `options.mdaModeCount`  target MDA prefix count; default source count
+ `options.modeTolerance`  allowed matched-mode physical shape residual

## Returns
+ `other`  new transform with transferred state, t/t0 and forcing
+ `assessment`  positive physical transfer and discarded-content diagnostics

## Discussion

Retained counts default to the source counts, independently of Nz. Target
scientific construction may solve modes; failed qualification rejects the
requested resolution without silently dropping modes. Normalization and
shape matching use coefficientStateForTransform. Forcing conversion is
explicit and an unsupported conversion rejects the whole operation.
