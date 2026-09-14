---
layout: default
title: projectQuasigeostrophicSpatialTendency
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 167
mathjax: true
---

#  projectQuasigeostrophicSpatialTendency

Project physical QGPV and strict endpoint-displacement rates with the weak dual.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `Fq`  real Nx-by-Ny-by-Nz QGPV tendency in s^-2
+ `Fb`  real Nx-by-Ny-by-2 endpoint tendency in m/s

## Returns
+ `tendency`  family-keyed coefficient rates

## Discussion
Native source samples are interpolated to independent physical quadrature.
