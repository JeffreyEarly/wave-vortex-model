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
+ `options.N2Function`  squared buoyancy-frequency function. Supply one of N2Function, rhoFunction, and rhoSpline.
+ `options.rhoFunction`  no-motion density function
+ `options.rhoSpline`  no-motion density BSpline in kg m^{-3} on [-Lz,0]. Its analytic derivative defines N2 and its interior knots guide the smoothed-bandwidth filter.
+ `options.rho0`  Boussinesq reference density. Defaults to the supplied surface density for rhoFunction or rhoSpline and to 1025 for N2Function.
+ `options.g0`  surface acceleration; default negative stratification integral
+ `options.gd`  bottom acceleration; default positive stratification integral
+ `options.latitude`  latitude in degrees; default 24
+ `options.apvModeCount`  strict retained APV prefix; empty preserves automatic selection
+ `options.mdaModeCount`  strict retained MDA prefix; empty preserves automatic selection
+ `options.gramTolerance`  shared normalized-Gram tolerance; default 1e-2
+ `options.modeConvergenceTolerance`  independent physical H1 and equivalent-depth agreement; default 1e-6
+ `options.boundaryResolutionTolerance`  fixed zero-APV physical derivative and energy tolerance; default 1e-2
+ `options.verticalGridRule`  smoothedBandwidth (default) or wkb
+ `options.quadraticDealiasing`  vertical policy none, fixedFraction, or effectiveBandwidth; default fixedFraction
+ `options.retainedFraction`  fixedFraction retained share of the linear APV prefix; default 2/3
+ `options.energyFraction`  effectiveBandwidth cumulative spectral-energy fraction; default 0.99
+ `options.bandwidthFraction`  effectiveBandwidth share of the vertical grid degree; default 2/3
+ `options.muTolerance`  APV inversion singularity tolerance

## Returns
+ `wvt`  new `WVTransformFreeSurfaceQG` instance

## Discussion

Omitted `g0` uses $$-\int_{-D}^{0}N^2\,dz$$ and omitted `gd`
uses $$+\int_{-D}^{0}N^2\,dz$$, activating both endpoints.
Use `gd=Inf` to omit the bottom endpoint. A finite endpoint,
including zero, activates one boundary-normalized zero-APV
family row. Supplying every
persisted mode/operator option selects the direct construction
path and performs no InternalModes solve.
