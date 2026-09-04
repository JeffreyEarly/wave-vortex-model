---
layout: default
title: boundaryMomentumTendency
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 59
mathjax: true
---

#  boundaryMomentumTendency

Project momentum stress per unit density onto the signed balanced basis.

> Developer documentation: this item describes internal implementation details.


---

## Discussion
Stress inputs are compact nonzero-wavenumber Fourier rows in m^2 s^-2.
The zero-APV source uses the stored inverse signed Gram matrix and leaves
the public coefficients in their boundary-normalized coordinates.
