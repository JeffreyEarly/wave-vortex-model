---
layout: default
title: projectQuasigeostrophicSpatialTendency
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 171
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

Interior QGPV is projected into `Ag_q` first. The active-endpoint
tendency remaining after that APV response is projected into `Ag_0`.
Periodic horizontal advection gives the horizontal-mean `Amda` family an
exact zero tendency.
