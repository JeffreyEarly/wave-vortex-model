---
layout: default
title: WVTransformStratifiedQG
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 38
mathjax: true
---

#  WVTransformStratifiedQG

Create a stratified quasigeostrophic transform.


---

## Declaration
```matlab
 wvt = WVTransformStratifiedQG(Lxyz,Nxyz,options)
```
## Parameters
+ `Lxyz`  length of the domain (in meters) in the three coordinate directions, e.g. [Lx Ly Lz]
+ `Nxyz`  number of grid points in the three coordinate directions, e.g. [Nx Ny Nz]
+ `options.N2Function`  function returning squared buoyancy frequency on `[-Lz,0]`
+ `options.rhoFunction`  function returning density on `[-Lz,0]`
+ `options.latitude`  latitude in the supported domain; default `33`
+ `options.shouldAntialias`  exclude quadratically aliased modes; default `true`
+ `options.rho0`  reference density in kilograms per cubic meter; default `1025`

## Returns
+ `wvt`  new `WVTransformStratifiedQG` instance

## Discussion

Creates a new instance of the WVTransformStratifiedQG class
for quasigeostrophic flow in variable stratification.

Supply either `N2Function` or `rhoFunction`. This transform
represents the geostrophic `A0` coefficients and has no wave
`Ap` or `Am` content. Additional modal arrays accepted by the
constructor are reconstruction state used by persistence.
