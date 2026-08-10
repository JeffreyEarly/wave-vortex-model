---
layout: default
title: addNonhydrostaticSpatialForcing
parent: WVForcing
grand_parent: Forcing
nav_order: 3
mathjax: true
---

#  addNonhydrostaticSpatialForcing

Add nonhydrostatic physical-space tendencies.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [Fu,Fv,Fw,Feta] = addNonhydrostaticSpatialForcing(wvt,Fu,Fv,Fw,Feta)
```
## Parameters
+ `wvt`  transform evaluating the forcing
+ `Fu`  accumulated zonal-velocity tendency
+ `Fv`  accumulated meridional-velocity tendency
+ `Fw`  accumulated vertical-velocity tendency
+ `Feta`  accumulated isopycnal-displacement tendency

## Returns
+ `Fu`  updated zonal-velocity tendency
+ `Fv`  updated meridional-velocity tendency
+ `Fw`  updated vertical-velocity tendency
+ `Feta`  updated isopycnal-displacement tendency

## Discussion

Subclasses declaring `NonhydrostaticSpatial` override this hook.
