---
layout: default
title: placeParticlesOnIsopycnal
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 192
mathjax: true
---

#  placeParticlesOnIsopycnal

Return particle depths on the isopycnal identified by a no-motion depth.


---

## Declaration
```matlab
 zIsopycnal = placeParticlesOnIsopycnal(x,y,zNoMotion)
```
## Parameters
+ `x`  array of particle x positions
+ `y`  array of particle y positions
+ `zNoMotion`  depths identifying target densities in the no-motion profile

## Returns
+ `zIsopycnal`  particle depths in meters

## Discussion

Given particle position (x,y), `zNoMotion` is used to determine the target
isopycnal using the no-motion density,

```matlab
targetRho = wvt.rhoFunction(zNoMotion);
```

and a minimization algorithm is used to find zIsopycnal such that

```matlab
zIsopycnal = rho(targetRho);
```

where `rho` is the current total density field of the fluid.

Note that the density is not necessarily monotonic, so the answer is not
necessarily unique.
