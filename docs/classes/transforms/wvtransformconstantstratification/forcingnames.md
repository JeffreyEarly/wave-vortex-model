---
layout: default
title: forcingNames
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 121
mathjax: true
---

#  forcingNames

Return forcing and closure names in application order.


---

## Declaration
```matlab
 names = forcingNames()
```
## Returns
+ `names`  column string array of registered forcing and closure names

## Discussion
Return forcing and closure names in application order.

Names are ordered by the three forcing stages: physical-space flux, spectral flux, and spectral-amplitude modification.
