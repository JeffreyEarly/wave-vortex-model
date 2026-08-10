---
layout: default
title: WVVerticalDamping
parent: WVVerticalDamping
grand_parent: Closures
nav_order: 1
mathjax: true
---

#  WVVerticalDamping

Create vertical Laplacian damping for a transform.


---

## Declaration
```matlab
 self = WVVerticalDamping(wvt,options)
```
## Parameters
+ `wvt`  wave-bearing three-dimensional transform that owns the closure
+ `nu`  optional vertical viscosity in square meters per second; default `5e-4`
+ `kappa`  optional vertical diffusivity in square meters per second; default `1e-6`

## Returns
+ `self`  vertical-damping closure owned by `wvt`

## Discussion
