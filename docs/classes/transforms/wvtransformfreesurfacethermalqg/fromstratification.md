---
layout: default
title: fromStratification
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 87
mathjax: true
---

#  fromStratification

Construct a complete thermal basis and independently resolved MDA modes.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `domainSize`  three physical lengths in m
+ `gridSize`  horizontal grid counts and increasing WKB Lobatto count
+ `options.N2Function`  positive constant or exponential N2 profile
+ `options.thermalModeCount`  complete polynomial-space dimension
+ `options.mdaModeCount`  independently retained mean dimension
+ `options.shouldCheckQuadraticAliasing`  qualify mapped product quadrature for nonlinear registration
+ `options.nonlinearQuadratureCount`  independent product count; zero selects max(257,3*n+1)
+ `options.nonlinearQuadratureTolerance`  weighted moment Gram allowance, default 1e-8

## Returns
+ `w`  thermal transform with zero coefficients

## Discussion
Native sampling and assembly quadrature do not truncate thermal directions.
