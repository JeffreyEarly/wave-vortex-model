---
layout: default
title: setPotentialVorticitySpectralAmplitude
parent: WVForcing
grand_parent: Forcing
nav_order: 16
mathjax: true
---

#  setPotentialVorticitySpectralAmplitude

Restore selected QG coefficients after a model step.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 A0 = setPotentialVorticitySpectralAmplitude(wvt,A0)
```
## Parameters
+ `wvt`  QG transform evaluating the forcing
+ `A0`  zero-frequency coefficients

## Returns
+ `A0`  updated zero-frequency coefficients

## Discussion

Subclasses declaring `PVSpectralAmplitude` override this hook.
