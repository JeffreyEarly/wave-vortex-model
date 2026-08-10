---
layout: default
title: addHydrostaticSpatialForcing
parent: WVForcing
grand_parent: Forcing
nav_order: 2
mathjax: true
---

#  addHydrostaticSpatialForcing

Add hydrostatic physical-space tendencies.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [Fu,Fv,Feta] = addHydrostaticSpatialForcing(wvt,Fu,Fv,Feta)
```
## Parameters
+ `wvt`  transform evaluating the forcing
+ `Fu`  accumulated zonal-velocity tendency
+ `Fv`  accumulated meridional-velocity tendency
+ `Feta`  accumulated isopycnal-displacement tendency

## Returns
+ `Fu`  updated zonal-velocity tendency
+ `Fv`  updated meridional-velocity tendency
+ `Feta`  updated isopycnal-displacement tendency

## Discussion

Subclasses declaring `HydrostaticSpatial` override this hook.
