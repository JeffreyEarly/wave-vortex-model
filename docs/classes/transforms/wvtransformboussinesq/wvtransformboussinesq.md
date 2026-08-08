---
layout: default
title: WVTransformBoussinesq
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 69
mathjax: true
---

#  WVTransformBoussinesq

Create a nonhydrostatic wave-vortex transform for variable stratification.


---

## Declaration
```matlab
 wvt = WVTransformBoussinesq(Lxyz,Nxyz,options)
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
+ `wvt`  new `WVTransformBoussinesq` instance

## Discussion

Creates a new instance of the WVTransformBoussinesq class
appropriate for disentangling nonhydrostatic waves and vortices
in variable stratification

Supply either `N2Function` or `rhoFunction`. The additional
modal arrays accepted by the constructor are reconstruction
state used by the persistence factories rather than ordinary
user construction options.
