---
layout: default
title: modeNumberFromIndex
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 198
mathjax: true
---

#  modeNumberFromIndex

Return mode numbers for spectral linear indices.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [kMode,lMode,jMode] = modeNumberFromIndex(linearIndex)
```
## Parameters
+ `linearIndex`  positive integer scalar or column vector

## Returns
+ `kMode`  integer scalar or column vector
+ `lMode`  integer scalar or column vector
+ `jMode`  integer scalar or column vector

## Discussion

Scalar and column-vector inputs preserve their shape and ordering. Each
index must lie within the current spectral matrix.
