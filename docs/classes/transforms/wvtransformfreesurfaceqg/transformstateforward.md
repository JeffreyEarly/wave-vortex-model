---
layout: default
title: transformStateForward
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 241
mathjax: true
---

#  transformStateForward

Recover coefficients from sampled APV and endpoint anomalies.


---

## Declaration
```matlab
 [Ag_q,Ag_0] = transformStateForward(self,APV,endpointAnomalies)
```
## Parameters
+ `APV`  sampled APV array with shape `Nz × NklNonzero`
+ `endpointAnomalies`  active endpoint anomalies with shape `Ne × NklNonzero`

## Returns
+ `Ag_q`  generalized-energy APV coefficients
+ `Ag_0`  boundary-normalized zero-APV coefficients

## Discussion

This sampled inversion uses the APV F inversion matrix. The physical
QGPV projection functional is used by `projectQuasigeostrophicSpatialTendency`.
