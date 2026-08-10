---
layout: default
title: WVFixedAmplitudeForcing
parent: WVFixedAmplitudeForcing
grand_parent: Forcing
nav_order: 7
mathjax: true
---

#  WVFixedAmplitudeForcing

Create fixed-amplitude forcing for selected coefficients.


---

## Declaration
```matlab
 self = WVFixedAmplitudeForcing(wvt,options)
```
## Parameters
+ `wvt`  transform that owns and evaluates the forcing
+ `name`  required unique forcing-registry name
+ `Apbar`  optional column of prescribed `Ap` values; default empty
+ `Ambar`  optional column of prescribed `Am` values; default empty
+ `A0bar`  optional column of prescribed `A0` values; default empty
+ `Ap_indices`  optional column of corresponding `Ap` linear indices; default empty
+ `Am_indices`  optional column of corresponding `Am` linear indices; default empty
+ `A0_indices`  optional column of corresponding `A0` linear indices; default empty

## Returns
+ `self`  fixed-amplitude forcing owned by `wvt`

## Discussion

Supply a unique registry name. Coefficients may be selected
directly with paired value/index column vectors, or later with
`setWaveForcingCoefficients` and
`setGeostrophicForcingCoefficients`.

See the [WVFixedAmplitudeForcing overview](/classes/forcing/wvfixedamplitudeforcing/)
for the tendency and restoration behavior, modeling cautions,
and a usage example.
