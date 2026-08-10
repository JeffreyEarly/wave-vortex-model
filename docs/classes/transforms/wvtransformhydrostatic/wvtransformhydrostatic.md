---
layout: default
title: WVTransformHydrostatic
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 57
mathjax: true
---

#  WVTransformHydrostatic

Create a hydrostatic wave-vortex transform for variable stratification.


---

## Declaration
```matlab
 wvt = WVTransformHydrostatic(Lxyz, Nxyz, options)
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
+ `wvt`  new `WVTransformHydrostatic` instance

## Discussion

Creates a new instance of the WVTransformHydrostatic class
appropriate for disentangling hydrostatic waves and vortices
in variable stratification

Supply either `N2Function` or `rhoFunction`. The additional
modal arrays accepted by the constructor are reconstruction
state used by the persistence factories rather than ordinary
user construction options.
