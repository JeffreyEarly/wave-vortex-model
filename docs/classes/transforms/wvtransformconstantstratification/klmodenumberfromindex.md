---
layout: default
title: klModeNumberFromIndex
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 174
mathjax: true
---

#  klModeNumberFromIndex

return mode number from a linear index into a WV matrix

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [kMode,lMode] = klModeNumberFromIndex(self,linearIndex)
```
## Parameters
+ `linearIndex`  a non-negative integer number

## Returns
+ `kMode`  integer
+ `lMode`  integer

## Discussion

This function will return the mode numbers (kMode,lMode)
given some linear index into a WV structured matrix. Scalar
and column-vector inputs preserve their shape and ordering.
