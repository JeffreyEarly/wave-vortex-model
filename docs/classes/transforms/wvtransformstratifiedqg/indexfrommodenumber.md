---
layout: default
title: indexFromModeNumber
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 81
mathjax: true
---

#  indexFromModeNumber

return the linear index into a spectral matrix given (k,l,j)

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 index = indexFromModeNumber(kMode,lMode,jMode)
```
## Parameters
+ `kMode`  integer
+ `lMode`  integer
+ `jMode`  integer vertical mode number present in `self.j`

## Returns
+ `index`  a non-negative integer number

## Discussion

This function will return the linear index in a spectral
matrix given a mode number. Scalar and column-vector inputs preserve
their shape and ordering; conjugate mode numbers map to their primary
coefficient.
