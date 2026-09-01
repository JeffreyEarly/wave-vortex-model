---
layout: default
title: addQuasigeostrophicSpectralForcing
parent: WVForcing
grand_parent: Forcing
nav_order: 7
mathjax: true
---

#  addQuasigeostrophicSpectralForcing

Add a free-surface QG coefficient-family tendency.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 tendency = addQuasigeostrophicSpectralForcing(wvt,tendency)
```
## Parameters
+ `wvt`  free-surface QG transform evaluating the forcing
+ `tendency`  accumulated family-keyed coefficient tendency

## Returns
+ `tendency`  updated family-keyed coefficient tendency

## Discussion

Subclasses declaring `QGSpectral` override this hook. The
scalar input and output structure contains the transform's
canonical `Ag_q`, `Ag_0`, and `Amda` families.
