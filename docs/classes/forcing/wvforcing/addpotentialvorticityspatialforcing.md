---
layout: default
title: addPotentialVorticitySpatialForcing
parent: WVForcing
grand_parent: Forcing
nav_order: 4
mathjax: true
---

#  addPotentialVorticitySpatialForcing

Add a physical-space QGPV tendency.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 F0 = addPotentialVorticitySpatialForcing(wvt,F0)
```
## Parameters
+ `wvt`  QG transform evaluating the forcing
+ `F0`  accumulated physical-space QGPV tendency

## Returns
+ `F0`  updated physical-space QGPV tendency

## Discussion

Subclasses declaring `PVSpatial` override this hook.
