---
layout: default
title: setGeostrophicForcingCoefficients
parent: WVFixedAmplitudeForcing
grand_parent: Forcing
nav_order: 9
mathjax: true
---

#  setGeostrophicForcingCoefficients

Select zero-frequency coefficients to fix.


---

## Declaration
```matlab
 setGeostrophicForcingCoefficients(A0bar,options)
```
## Parameters
+ `A0bar`  `A0` values on the transform spectral grid
+ `MA0`  optional logical `A0` selection mask; default `abs(A0bar) > 1e-6*max(abs(A0bar(:)))`

## Discussion

Without an explicit mask, coefficients whose magnitude is at
least $$10^{-6}$$ times the largest supplied magnitude are
selected. If adaptive damping is registered, selected modes
above its horizontal `k_damp` threshold are removed.
