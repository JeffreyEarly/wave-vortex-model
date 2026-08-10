---
layout: default
title: WVThermalDamping
parent: WVThermalDamping
grand_parent: Closures
nav_order: 1
mathjax: true
---

#  WVThermalDamping

Create thermal damping for a QG transform.


---

## Declaration
```matlab
 self = WVThermalDamping(wvt,options)
```
## Parameters
+ `wvt`  stratified or barotropic QG transform that owns the forcing
+ `alpha`  optional damping rate in inverse seconds; default `1/(200*86400)`

## Returns
+ `self`  thermal-damping forcing owned by `wvt`

## Discussion
