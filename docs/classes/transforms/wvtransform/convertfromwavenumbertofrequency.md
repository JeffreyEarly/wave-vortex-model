---
layout: default
title: convertFromWavenumberToFrequency
parent: WVTransform
grand_parent: Transforms
nav_order: 23
mathjax: true
---

#  convertFromWavenumberToFrequency

Bin wave energy by vertical mode and intrinsic frequency


---

## Declaration
```matlab
 [energyFrequency,omegaVector] = wvt.convertFromWavenumberToFrequency()
```
## Returns
+ `energyFrequency`  wave energy for each vertical mode and frequency bin, with dimensions `Nj`-by-`numel(omegaVector)`
+ `omegaVector`  intrinsic-frequency bin coordinates

## Discussion

Redistributes the energy in the stored Ap and Am coefficients from the
horizontal-wavenumber grid onto uniformly spaced intrinsic-frequency bins.
