---
layout: default
title: variableAtPositionWithName
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 244
mathjax: true
---

#  variableAtPositionWithName

Access dynamical variables at arbitrary positions in the domain.


---

## Declaration
```matlab
 [varargout] = variableAtPositionWithName(x,y,z,variableNames,options)
```
## Parameters
+ `x`  array of x-positions
+ `y`  array of y-positions
+ `z`  array of z-positions, or empty for two-dimensional variables
+ `variableNames`  strings of variable names.
+ `options.interpolationMethod`  periodic `linear` or cubic `spline` interpolation; default `linear`

## Returns
+ `varargout`  interpolated arrays in the requested order and query shape

## Discussion

Computes (or retrieves from cache) any known state variables and computes
their values at the requested positions (x,y,z). For two-dimensional
variables, interpolation uses only (x,y), and z may be empty.

The interpolation method may be `linear` or `spline`. Horizontal
coordinates are wrapped periodically before interpolation.

```matlab
[u,v] = wvt.variableAtPositionWithName(xParticle,yParticle,zParticle,'u','v',interpolationMethod='spline');
```
