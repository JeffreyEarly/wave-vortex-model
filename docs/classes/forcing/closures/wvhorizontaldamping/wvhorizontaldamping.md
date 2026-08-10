---
layout: default
title: WVHorizontalDamping
parent: WVHorizontalDamping
grand_parent: Closures
nav_order: 1
mathjax: true
---

#  WVHorizontalDamping

Create horizontal Laplacian damping for a transform.


---

## Declaration
```matlab
 self = WVHorizontalDamping(wvt,options)
```
## Parameters
+ `wvt`  wave-bearing three-dimensional transform that owns the closure
+ `nu`  optional horizontal viscosity in square meters per second; default `1e-4`
+ `kappa`  optional horizontal diffusivity in square meters per second; default `1e-6`

## Returns
+ `self`  horizontal-damping closure owned by `wvt`

## Discussion
