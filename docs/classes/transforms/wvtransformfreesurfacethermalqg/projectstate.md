---
layout: default
title: projectState
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 178
mathjax: true
---

#  projectState

Fit QGPV in physical-depth least squares with exact endpoint constraints.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `qgpv`  real Nx-by-Ny-by-Nz QGPV in inverse seconds
+ `endpointAnomalies`  real Nx-by-Ny-by-2 displacement in m
+ `options.meanDisplacement`  sampled horizontal-mean displacement in m

## Returns
+ `state`  Ath and Amda arrays without modifying this transform
+ `residual`  physical RMS QGPV and separate endpoint fit residuals

## Discussion
This state fit is distinct from the weak physical tendency projector.
