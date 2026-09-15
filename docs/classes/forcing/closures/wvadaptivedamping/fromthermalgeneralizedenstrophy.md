---
layout: default
title: fromThermalGeneralizedEnstrophy
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 12
mathjax: true
---

#  fromThermalGeneralizedEnstrophy

Construct native thermal generalized-enstrophy damping.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 self = fromThermalGeneralizedEnstrophy(wvt,options)
```
## Parameters
+ `wvt`  thermal transform that owns the closure
+ `options.generalizedEnstrophyCutoffFraction`  ordinal cutoff fraction in [0,1), or NaN for the standard cutoff
+ `options.boundaryWeightMultiplier`  positive common multiplier for both endpoint weights

## Returns
+ `self`  native thermal adaptive-damping closure

## Discussion

This factory assembles a complete positive generalized spectrum
in the transform's polynomial space. The endpoint multiplier
applies equally to surface and bottom variance weights.
