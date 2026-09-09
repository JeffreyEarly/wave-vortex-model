---
layout: default
title: assessVerticalResolution
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 55
mathjax: true
---

#  assessVerticalResolution

Assess vertical-mode accuracy and the active-endpoint horizontal limit.


---

## Declaration
```matlab
 assessment = WVTransformFreeSurfaceQG.assessVerticalResolution(Lz,Nz,options)
```
## Parameters
+ `Lz`  vertical domain depth in meters
+ `Nz`  number of physical vertical quadrature points
+ `options.N2Function`  squared buoyancy-frequency function
+ `options.rhoFunction`  no-motion density function
+ `options.g0`  surface acceleration; default negative stratification integral
+ `options.gd`  bottom acceleration; default positive stratification integral; use Inf to omit the bottom endpoint
+ `options.latitude`  latitude in degrees; default 24
+ `options.gramTolerance`  shared normalized-Gram tolerance; default 1e-2
+ `options.modeConvergenceTolerance`  independent physical H1 and equivalent-depth agreement; default 1e-6
+ `options.boundaryResolutionTolerance`  fixed zero-APV physical derivative and energy tolerance; default 1e-2
+ `options.shouldCheckQuadraticAliasing`  qualify quadratic products during construction; default true
+ `options.quadraticAliasingTolerance`  APV quadratic-product tolerance

## Returns
+ `assessment`  data-only vertical-resolution diagnostics

## Discussion

This method performs the scientific vertical solve without constructing a
complete horizontal transform. For active endpoint families it returns a
conservative maximum horizontal wavenumber whose fixed boundary responses
satisfy `boundaryResolutionTolerance`. When `shouldCheckQuadraticAliasing`
is true, APV/zero-APV products must also satisfy `quadraticAliasingTolerance`.
The two relative errors and their tolerances remain separate; unrequested
quadratic errors are NaN.
