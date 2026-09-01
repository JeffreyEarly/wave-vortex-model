---
layout: default
title: setSpectralAmplitude
parent: WVForcing
grand_parent: Forcing
nav_order: 19
mathjax: true
---

#  setSpectralAmplitude

Restore selected wave-vortex coefficients after a model step.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [Ap,Am,A0] = setSpectralAmplitude(wvt,Ap,Am,A0)
```
## Parameters
+ `wvt`  transform evaluating the forcing
+ `Ap`  positive-frequency coefficients
+ `Am`  negative-frequency coefficients
+ `A0`  zero-frequency coefficients

## Returns
+ `Ap`  updated positive-frequency coefficients
+ `Am`  updated negative-frequency coefficients
+ `A0`  updated zero-frequency coefficients

## Discussion

Subclasses declaring `SpectralAmplitude` override this hook to
enforce their constrained coefficient values exactly.
