---
layout: default
title: forcingFromGroup
parent: WVForcing
grand_parent: Forcing
nav_order: 9
mathjax: true
---

#  forcingFromGroup

Restore a concrete forcing from a NetCDF group.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 force = forcingFromGroup(group,wvt)
```
## Parameters
+ `group`  NetCDF group containing annotated forcing state
+ `wvt`  transform that will own the restored forcing

## Returns
+ `force`  restored concrete `WVForcing` instance

## Discussion

The annotated class name and required properties select and
reconstruct the concrete forcing subclass.
