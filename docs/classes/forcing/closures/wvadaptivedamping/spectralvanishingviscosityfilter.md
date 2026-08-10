---
layout: default
title: spectralVanishingViscosityFilter
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 11
mathjax: true
---

#  spectralVanishingViscosityFilter

Build horizontal and vertical spectral-vanishing filters.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [Qkl,Qj,kl_cutoff,kl_damp,j_cutoff,j_damp] = spectralVanishingViscosityFilter(kl_max,j_max)
```
## Parameters
+ `kl_max`  maximum resolved horizontal wavenumber in radians per meter
+ `j_max`  maximum resolved vertical-mode number

## Returns
+ `Qkl`  horizontal filter on the spectral grid
+ `Qj`  vertical filter on the spectral grid
+ `kl_cutoff`  exact horizontal zero-damping cutoff in radians per meter
+ `kl_damp`  estimated horizontal significant-damping wavenumber in radians per meter
+ `j_cutoff`  exact vertical zero-damping cutoff
+ `j_damp`  estimated vertical significant-damping mode

## Discussion
