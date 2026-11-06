---
layout: default
title: projectQuasigeostrophicSpatialTendency
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 185
mathjax: true
---

#  projectQuasigeostrophicSpatialTendency

Project physical QG tendencies into canonical coefficient families.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 tendency = projectQuasigeostrophicSpatialTendency(self,Fq,Fb)
```
## Parameters
+ `Fq`  physical QGPV tendency with shape `Nx × Ny × Nz`
+ `Fb`  endpoint-anomaly tendency with shape `Nx × Ny × Ne`

## Returns
+ `tendency`  family-keyed coefficient tendency

## Discussion

The physical APV F projection functional gives `Ag_q` from interior
QGPV. The active-endpoint tendency remaining after that APV response
determines `Ag_0`.
Periodic horizontal advection gives the horizontal-mean `Amda` family an
exact zero tendency.
