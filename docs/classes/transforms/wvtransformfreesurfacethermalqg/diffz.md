---
layout: default
title: diffZ
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 68
mathjax: true
---

#  diffZ

Differentiate physical-grid samples once or twice using mapped FFT calculus.


---

## Parameters
+ `field`  real or complex Nx-by-Ny-by-Nz samples
+ `order`  derivative order, 1 or 2

## Returns
+ `derivative`  physical vertical derivative with the input shape
