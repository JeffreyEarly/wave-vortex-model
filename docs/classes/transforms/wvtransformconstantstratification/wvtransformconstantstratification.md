---
layout: default
title: WVTransformConstantStratification
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 68
mathjax: true
---

#  WVTransformConstantStratification

Create a wave-vortex transform for constant stratification.


---

## Declaration
```matlab
 wvt = WVTransformConstantStratification(Lxyz,Nxyz,options)
```
## Parameters
+ `Lxyz`  length of the domain (in meters) in the three coordinate directions, e.g. [Lx Ly Lz]
+ `Nxyz`  number of grid points in the three coordinate directions, e.g. [Nx Ny Nz]
+ `options.N0`  constant buoyancy frequency in radians per second; default `5.2e-3`
+ `options.isHydrostatic`  use hydrostatic dynamics; default `false`
+ `options.latitude`  latitude in the supported domain; default `33`
+ `options.shouldAntialias`  exclude quadratically aliased modes; default `true`
+ `options.rho0`  reference density in kilograms per cubic meter; default `1025`

## Returns
+ `wvt`  new `WVTransformConstantStratification` instance

## Discussion

Creates a new instance of the WVTransformConstantStratification
class appropriate for disentangling waves and vortices in
constant stratification.

Set `isHydrostatic=true` for hydrostatic dynamics; the default
is the nonhydrostatic transform. `N0` is the constant buoyancy
frequency. The remaining geometry options configure the
rotating, doubly periodic domain.
