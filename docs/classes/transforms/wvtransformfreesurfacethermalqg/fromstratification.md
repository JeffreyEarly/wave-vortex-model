---
layout: default
title: fromStratification
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 83
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

## Returns
+ `w`  thermal transform with zero coefficients

## Discussion
Native sampling and assembly quadrature do not truncate thermal directions.
