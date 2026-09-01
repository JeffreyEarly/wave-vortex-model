---
layout: default
title: coefficientTendency
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 63
mathjax: true
---

#  coefficientTendency

Evaluate the family-keyed free-surface QG tendency.


---

## Declaration
```matlab
 tendency = coefficientTendency(self)
```
## Returns
+ `tendency`  scalar structure with `Ag_q`, `Ag_0`, and `Amda` tendencies

## Discussion

Every registered `QGSpatial` object contributes an interior
QGPV tendency and active-endpoint anomaly tendencies. Their
accumulated physical state is projected APV first and residual
zero APV second; `Amda` remains exactly zero.
