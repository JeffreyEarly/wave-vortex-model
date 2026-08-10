---
layout: default
title: addPotentialVorticitySpectralForcing
parent: WVForcing
grand_parent: Forcing
nav_order: 5
mathjax: true
---

#  addPotentialVorticitySpectralForcing

Add a spectral QGPV tendency.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 F0 = addPotentialVorticitySpectralForcing(wvt,F0)
```
## Parameters
+ `wvt`  QG transform evaluating the forcing
+ `F0`  accumulated spectral QGPV tendency

## Returns
+ `F0`  updated spectral QGPV tendency

## Discussion

Subclasses declaring `PVSpectral` override this hook.
