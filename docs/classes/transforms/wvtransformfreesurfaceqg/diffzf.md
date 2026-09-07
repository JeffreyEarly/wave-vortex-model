---
layout: default
title: diffZF
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 77
mathjax: true
---

#  diffZF

Differentiate a sampled field without projecting onto the APV F modes.


---

## Declaration
```matlab
 du = diffZF(u,n=n)
```
## Parameters
+ `u`  real or complex sampled field with shape `Nx x Ny x Nz`
+ `n`  physical derivative order from 1 through 4; default 1

## Returns
+ `du`  sampled physical derivative with the same shape as u

## Discussion

This free-surface alias uses `diffZ` on the shared physical grid.
APV, zero-APV, MDA, and general sampled fields use the same derivative;
the F suffix does not select a modal subspace or an output family.
