---
layout: default
title: assessVerticalResolution
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 56
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
+ `options.apvGramTolerance`  APV normalized-Gram tolerance
+ `options.mdaGramTolerance`  MDA normalized-Gram tolerance
+ `options.quadraticAliasingTolerance`  APV quadratic-product tolerance

## Returns
+ `assessment`  data-only vertical-resolution diagnostics

## Discussion

This method performs the scientific vertical solve without constructing a
complete horizontal transform. For active endpoint families it returns a
conservative maximum horizontal wavenumber whose APV/zero-APV product
error satisfies `quadraticAliasingTolerance`.
