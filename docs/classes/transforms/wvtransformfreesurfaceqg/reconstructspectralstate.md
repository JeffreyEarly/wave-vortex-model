---
layout: default
title: reconstructSpectralState
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 189
mathjax: true
---

#  reconstructSpectralState

Reconstruct compact spectral streamfunction, displacement, and full QGPV.


---

## Declaration
```matlab
 [psiHat,etaHat,qHat] = reconstructSpectralState(self)
```
## Returns
+ `psiHat`  streamfunction on the compact full-kl grid
+ `etaHat`  displacement on the compact full-kl grid
+ `qHat`  full QGPV, including MDA, on the compact full-kl grid

## Discussion

The zero-horizontal-wavenumber displacement is the MDA field, with
$$\overline q = -f\partial_z\overline\eta_i.$$ The mean SSH
gauge is zero. Nonzero-wavenumber QGPV is reconstructed from APV modes.
