---
layout: default
title: setWaveForcingCoefficients
parent: WVNarrowBandGeostrophicForcing
grand_parent: Forcing
nav_order: 17
mathjax: true
---

#  setWaveForcingCoefficients

Select positive- and negative-frequency coefficients to fix.


---

## Declaration
```matlab
 setWaveForcingCoefficients(Apbar,Ambar,options)
```
## Parameters
+ `Apbar`  `Ap` values on the transform spectral grid
+ `Ambar`  `Am` values on the transform spectral grid
+ `MAp`  optional logical `Ap` selection mask; default `abs(Apbar) > 1e-6*max(abs(Apbar(:)))`
+ `MAm`  optional logical `Am` selection mask; default `abs(Ambar) > 1e-6*max(abs(Ambar(:)))`

## Discussion

Without explicit masks, coefficients whose magnitude is at
least $$10^{-6}$$ times the largest supplied magnitude are
selected. If adaptive damping is registered, selected modes
above its horizontal `k_damp` threshold are removed.
