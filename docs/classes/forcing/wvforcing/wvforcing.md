---
layout: default
title: WVForcing
parent: WVForcing
grand_parent: Forcing
nav_order: 1
mathjax: true
---

#  WVForcing

Initialize the base state for a forcing subclass.


---

## Declaration
```matlab
 self = WVForcing(wvt,name,forcingType)
```
## Parameters
+ `wvt`  transform that owns and evaluates the forcing
+ `name`  unique forcing registry name
+ `forcingType`  one or more `WVForcingType` evaluation stages implemented by the subclass

## Returns
+ `self`  initialized `WVForcing` base instance

## Discussion

Subclass constructors call this constructor with their owning
transform, unique registry name, and implemented evaluation
stages. Users normally construct a concrete supplied subclass.
