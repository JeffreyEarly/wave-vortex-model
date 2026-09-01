---
layout: default
title: addQuasigeostrophicSpatialForcing
parent: WVForcing
grand_parent: Forcing
nav_order: 6
mathjax: true
---

#  addQuasigeostrophicSpatialForcing

Add interior and active-endpoint QG physical-space tendencies.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [Fq,Fb] = addQuasigeostrophicSpatialForcing(wvt,Fq,Fb,physicalState)
```
## Parameters
+ `wvt`  free-surface QG transform evaluating the forcing
+ `Fq`  accumulated physical-space QGPV tendency
+ `Fb`  accumulated active-endpoint anomaly tendency
+ `physicalState`  optional shared physical reconstruction

## Returns
+ `Fq`  updated physical-space QGPV tendency
+ `Fb`  updated active-endpoint anomaly tendency

## Discussion

`Fq` has the transform's `x`, `y`, and `z` dimensions. `Fb`
has `x`, `y`, and `activeEndpoint` dimensions; its third
dimension is zero when both endpoints are inactive. A forcing
declaring `QGSpatial` overrides this hook and returns both
accumulators in the same physical coordinates. During model
tendency evaluation, `physicalState` provides the shared
`q`, `u`, `v`, `b`, `ub`, and `vb` reconstruction. It is an
empty structure when the hook is called directly.
