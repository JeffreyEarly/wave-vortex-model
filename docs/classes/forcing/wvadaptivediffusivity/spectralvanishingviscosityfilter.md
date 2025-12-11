---
layout: default
title: spectralVanishingViscosityFilter
parent: WVAdaptiveDiffusivity
grand_parent: Classes
nav_order: 6
mathjax: true
---

#  spectralVanishingViscosityFilter

Builds the spectral vanishing viscosity operator


---

## Declaration
```matlab
 spectralVanishingViscosityFilter(self, options)
```
## Parameters
+ `self`  an instance of WVAdaptiveViscosity
+ `options`  struct with field shouldAssumeAntialiasing

## Discussion

        - Returns: Qkl, Qj, kl_cutoff, kl_damp
