---
layout: default
title: WVSeasonalSurfaceBuoyancyFlux
parent: WVSeasonalSurfaceBuoyancyFlux
grand_parent: Forcing
nav_order: 1
mathjax: true
---

#  WVSeasonalSurfaceBuoyancyFlux

Create seasonal surface buoyancy-flux forcing.


---

## Declaration
```matlab
 self = WVSeasonalSurfaceBuoyancyFlux(wvt,options)
```
## Parameters
+ `wvt`  free-surface QG transform with an active surface endpoint
+ `options.pattern`  exact finite real `Nx × Ny` pattern; default `sin(2*pi*y/Ly)`
+ `options.amplitude`  required peak buoyancy-flux amplitude in square meters per cubic second
+ `options.period`  positive period in seconds; default 365.25 days
+ `options.phase`  finite phase in radians; default zero

## Returns
+ `self`  seasonal surface buoyancy-flux forcing owned by `wvt`

## Discussion
