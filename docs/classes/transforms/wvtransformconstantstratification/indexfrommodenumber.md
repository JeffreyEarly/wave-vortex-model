---
layout: default
title: indexFromModeNumber
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 120
mathjax: true
---

#  indexFromModeNumber

return the linear index into a spectral matrix given (k,l,j)


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
