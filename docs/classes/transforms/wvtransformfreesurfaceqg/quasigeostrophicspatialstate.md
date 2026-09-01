---
layout: default
title: quasigeostrophicSpatialState
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 185
mathjax: true
---

#  quasigeostrophicSpatialState

Reconstruct the physical state used by QG spatial forcing.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [q,u,v,b,ub,vb] = quasigeostrophicSpatialState(self)
```
## Returns
+ `q`  interior QGPV
+ `u`  interior zonal velocity
+ `v`  interior meridional velocity
+ `b`  active-endpoint anomaly
+ `ub`  active-endpoint zonal velocity
+ `vb`  active-endpoint meridional velocity

## Discussion

Interior fields have shape `Nx × Ny × Nz`. Endpoint fields have shape
`Nx × Ny × Ne`, with active endpoints in canonical surface-bottom order.
