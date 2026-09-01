---
layout: default
title: transformStateForward
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 230
mathjax: true
---

#  transformStateForward

Project sampled APV first and residual endpoint anomalies second.


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
