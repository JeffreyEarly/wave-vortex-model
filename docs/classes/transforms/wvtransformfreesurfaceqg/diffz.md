---
layout: default
title: diffZ
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 78
mathjax: true
---

#  diffZ

Differentiate a sampled field on the shared physical vertical grid.


---

## Declaration
```matlab
 du = diffZ(u,n=n)
```
## Parameters
+ `u`  real or complex sampled field with shape `Nx x Ny x Nz`
+ `n`  physical derivative order from 1 through 4; default 1

## Returns
+ `du`  sampled physical derivative with the same shape as u

## Discussion

Apply the persisted physical first-derivative matrix successively:
$$\partial_z^n u \approx D_z^n u$$. No APV, zero-APV, or MDA
projection is performed. Each application differentiates the interpolant
of the preceding sampled derivative on the same mapped grid.

In the WKB coordinate $$s=\int_{-L_z}^z N\,dz'/\int_{-L_z}^0 N\,dz'$$,
$$D_z$$ includes the metric $$ds/dz=N/\int_{-L_z}^0 N\,dz'$$.
Successive application therefore differentiates the variable metric too;
it is not a constant-metric multiple of an nth coordinate derivative.
Accuracy depends on grid and map resolution, with higher orders more
sensitive to unresolved structure and floating-point error.

```matlab
dudz = wvt.diffZ(wvt.u);
```
