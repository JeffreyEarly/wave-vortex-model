---
layout: default
title: diffZG
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 80
mathjax: true
---

#  diffZG

Differentiate a sampled field without projecting onto the APV G modes.


---

## Declaration
```matlab
 du = diffZG(u,n=n)
```
## Parameters
+ `u`  real or complex sampled field with shape `Nx x Ny x Nz`
+ `n`  physical derivative order from 1 through 4; default 1

## Returns
+ `du`  sampled physical derivative with the same shape as u

## Discussion

This free-surface alias uses `diffZ` on the shared physical grid.
APV, zero-APV, MDA, and general sampled fields use the same derivative;
the G suffix does not select a modal subspace or an output family.
