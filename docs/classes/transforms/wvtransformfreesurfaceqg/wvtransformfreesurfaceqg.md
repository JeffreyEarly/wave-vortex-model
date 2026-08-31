---
layout: default
title: WVTransformFreeSurfaceQG
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 27
mathjax: true
---

#  WVTransformFreeSurfaceQG

Create a free-surface QG transform scientifically or directly.


---

## Declaration
```matlab
 wvt = WVTransformFreeSurfaceQG(Lxyz,Nxyz,options)
```
## Parameters
+ `Lxyz`  domain lengths `[Lx Ly Lz]` in meters
+ `Nxyz`  grid counts `[Nx Ny Nz]`
+ `options.N2Function`  squared buoyancy-frequency function
+ `options.rhoFunction`  no-motion density function
+ `options.g0`  surface acceleration; default stratification integral
+ `options.gd`  bottom acceleration; default `Inf`
+ `options.z`  physical vertical grid
+ `options.Nj`  requested common retained mode count

## Returns
+ `wvt`  new `WVTransformFreeSurfaceQG` instance

## Discussion

Omitted `g0` uses $$-\int_{-D}^{0}N^2\,dz$$ and omitted `gd`
is `Inf`. A finite endpoint, including zero, activates one
boundary-normalized zero-APV family row. Supplying every
persisted mode/operator option selects the direct construction
path and performs no InternalModes solve.
