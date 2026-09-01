---
layout: default
title: setPotentialVorticitySpectralForcing
parent: WVForcing
grand_parent: Forcing
nav_order: 17
mathjax: true
---

#  setPotentialVorticitySpectralForcing

Modify QGPV tendencies for a spectral-amplitude constraint.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 F0 = setPotentialVorticitySpectralForcing(wvt,F0)
```
## Parameters
+ `wvt`  QG transform evaluating the forcing
+ `F0`  accumulated zero-frequency tendency

## Returns
+ `F0`  updated zero-frequency tendency

## Discussion

Subclasses declaring `PVSpectralAmplitude` override this hook.
