---
layout: default
title: reconstructSpectralState
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 190
mathjax: true
---

#  reconstructSpectralState

Reconstruct compact spectral streamfunction, displacement, and full QGPV.


---

## Declaration
```matlab
 [psiHat,etaHat,qHat] = reconstructSpectralState(options)
```
## Parameters
+ `options.flowComponent`  selector belonging to this transform; empty selects the full state

## Returns
+ `psiHat`  streamfunction on the compact full-kl grid
+ `etaHat`  displacement on the compact full-kl grid
+ `qHat`  full QGPV, including MDA, on the compact full-kl grid

## Discussion

The zero-horizontal-wavenumber displacement is the MDA field, with
$$\overline q = -f\partial_z\overline\eta_i.$$ The mean SSH
gauge is zero. Nonzero-wavenumber QGPV is reconstructed from APV modes.
