---
layout: default
title: setSpectralForcing
parent: WVForcing
grand_parent: Forcing
nav_order: 17
mathjax: true
---

#  setSpectralForcing

Modify tendencies for a spectral-amplitude constraint.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [Fp,Fm,F0] = setSpectralForcing(wvt,Fp,Fm,F0)
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

Subclasses declaring `SpectralAmplitude` override this hook to
cancel or replace the tendency of constrained coefficients.
