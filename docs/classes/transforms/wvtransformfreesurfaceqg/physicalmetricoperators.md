---
layout: default
title: physicalMetricOperators
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 168
mathjax: true
---

#  physicalMetricOperators

Return quadrature reconstruction and positive physical quadratic metrics.

> Developer documentation: this item describes internal implementation details.


---

## Returns
+ `operators`  quadrature, reconstruction arrays, and quadratic metrics

## Discussion

These value arrays depend only on stored, immutable scientific modes. They
are built lazily, shared by diagnostics and density diffusion, and rebuilt
after restoration. No forcing or integrator is required. All active-endpoint
combinations and every MDA mode are represented.

For each nonzero horizontal wavenumber, `pages` contains kinetic, interior
potential, and surface potential energy matrices. The common APV enstrophy
matrix is the exact continuous Gram matrix of the depth-normalized F modes,
`D*I`. The sampled quadrature Gram is only an approximation to this diagonal
physical metric and is reserved for transform construction and resolution
assessment. Compact nonzero Fourier coefficients count twice in physical
variance; quadraticDiagnostics applies the half-integral convention,
including the separate horizontal-mean contribution.
