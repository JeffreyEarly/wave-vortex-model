---
layout: default
title: addSpectralForcing
parent: WVForcing
grand_parent: Forcing
nav_order: 8
mathjax: true
---

#  addSpectralForcing

Add wave-vortex coefficient tendencies in spectral space.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [Fp,Fm,F0] = addSpectralForcing(wvt,Fp,Fm,F0)
```
## Parameters
+ `wvt`  transform evaluating the forcing
+ `Fp`  accumulated `Ap` tendency
+ `Fm`  accumulated `Am` tendency
+ `F0`  accumulated `A0` tendency

## Returns
+ `Fp`  updated `Ap` tendency
+ `Fm`  updated `Am` tendency
+ `F0`  updated `A0` tendency

## Discussion

Subclasses declaring `Spectral` override this hook.
