---
layout: default
title: placeParticlesOnIsopycnal
parent: WVTransformBoussinesq
grand_parent: Classes
nav_order: 174
mathjax: true
---

#  placeParticlesOnIsopycnal

places Lagrangian particles along a specified isopycnal


---

## Declaration
```matlab
 zIsopycnal = placeParticlesOnIsopycnal(x,y,z)
```
## Parameters
+ `x`  array of particle x positions
+ `y`  array of particle y positions
+ `z`  array of z location of target isopycnal in the no-motion profile

## Returns
+ `zIsopycnal`  particle depth

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
 
  where rho is the current total density field of the fluid.
 
  Note that the density is not necessarily monotonic, so the answer is not
  necessarily unique.
 
            
