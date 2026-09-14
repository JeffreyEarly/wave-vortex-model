---
layout: default
title: boundaryMomentumTendency
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 48
mathjax: true
---

#  boundaryMomentumTendency

Project boundary momentum stress with the physical-energy weak dual.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `tauXHat`  zonal stress, compact nonzero Fourier row
+ `tauYHat`  meridional stress, compact nonzero Fourier row
+ `endpoint`  surface or bottom

## Returns
+ `tendency`  Ath and Amda coefficient rates

## Discussion

Stress per unit density is in m2/s2. The load for a test streamfunction
is minus its endpoint trace times the stress curl. Thus the physical
energy rate is the horizontal mean of u*tauX+v*tauY, including the
free-surface energy in the authoritative thermal metric. Both endpoint
equations respond through the complete balanced inverse; no volume cell
or direct horizontal-mean source is introduced.
