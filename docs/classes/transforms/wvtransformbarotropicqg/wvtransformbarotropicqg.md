---
layout: default
title: WVTransformBarotropicQG
parent: WVTransformBarotropicQG
grand_parent: Transforms
nav_order: 28
mathjax: true
---

#  WVTransformBarotropicQG

Create an equivalent-barotropic quasigeostrophic transform.


---

## Declaration
```matlab
 wvt = WVTransformBarotropicQG(Lxy,Nxy,options)
```
## Parameters
+ `Lxy`  length of the domain (in meters) in the two coordinate directions, e.g. [Lx Ly]
+ `Nxy`  number of grid points in the two coordinate directions, e.g. [Nx Ny]
+ `shouldAntialias`  (optional) whether or not to de-alias for quadratic multiplications
+ `options.h`  equivalent depth in meters; default `0.8`
+ `options.latitude`  latitude in the supported domain; default `33`

## Returns
+ `wvt`  new `WVTransformBarotropicQG` instance

## Discussion

```matlab
Lxy = 50e3;
Nxy = 256;
wvt = WVTransformBarotropicQG([Lxy,Lxy],[Nxy,Nxy],h=0.8,latitude=30);
```
