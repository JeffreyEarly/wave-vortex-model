---
layout: default
title: physicalErrorNorms
parent: WVDensityDiffusionIntegrator
grand_parent: Developer internals
nav_order: 8
mathjax: true
---

#  physicalErrorNorms

RMS full QGPV, buoyancy, speed, and active-endpoint displacement.

> Developer documentation: this item describes internal implementation details.


---

## Discussion
Includes MDA means; compact nonzero Fourier entries count twice.
Fixed QR factors preserve positive quadrature norms without
repeatedly reconstructing fields on the vertical grid.
