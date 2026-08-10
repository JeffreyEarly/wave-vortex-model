---
layout: default
title: WVVerticalDiffusivity
parent: WVVerticalDiffusivity
grand_parent: Closures
nav_order: 1
mathjax: true
---

#  WVVerticalDiffusivity

Create vertical diffusivity for a three-dimensional transform.


---

## Declaration
```matlab
 self = WVVerticalDiffusivity(wvt,options)
```
## Parameters
+ `wvt`  wave-bearing or stratified-QG transform that owns the forcing
+ `kappa_z`  optional vertical diffusivity in square meters per second; default `1e-5`
+ `shouldForceMeanDensityAnomaly`  optional flag controlling the horizontally uniform mean-density-anomaly source; default `true`

## Returns
+ `self`  vertical-diffusivity forcing owned by `wvt`

## Discussion
