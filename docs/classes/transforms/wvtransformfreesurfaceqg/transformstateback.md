---
layout: default
title: transformStateBack
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 227
mathjax: true
---

#  transformStateBack

Reconstruct sampled APV and active endpoint anomalies.


---

## Declaration
```matlab
 [APV,endpointAnomalies] = transformStateBack(self,Ag_q,Ag_0)
```
## Parameters
+ `Ag_q`  APV coefficients with shape `apvModeCount × NklNonzero`
+ `Ag_0`  zero-APV coefficients with shape `Ne × NklNonzero`

## Returns
+ `APV`  sampled APV pages
+ `endpointAnomalies`  active endpoint-anomaly pages

## Discussion
