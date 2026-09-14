---
layout: default
title: coefficientStateForTransform
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 55
mathjax: true
---

#  coefficientStateForTransform

Fit a compatible thermal target to physical QGPV, endpoints and mean density.


---

## Parameters
+ `target`  thermal target with identical physics and diffusion
+ `options.quadratureCount`  common physical-depth Gauss count

## Returns
+ `state`  target-shaped Ath and Amda without modifying either object
+ `assessment`  positive physical error norms, energies and endpoint loss

## Discussion
Both transforms remain unchanged. Fourier integer pairs identify horizontal
content; thermal eigenvalue ordering never identifies vertical directions.
Nonzero QGPV is fitted in positive physical-depth least squares with exact
endpoint constraints. Mean displacement is independently fitted with exact
endpoint and integrated buoyancy constraints; an inadequate target mean
space rejects the transfer.
Residuals include discarded Fourier content and vertical fit error, retaining
all cross terms. They are errors of the reconstructed difference, never a
subtraction of two large energies. Refine quadrature to assess fit convergence.
