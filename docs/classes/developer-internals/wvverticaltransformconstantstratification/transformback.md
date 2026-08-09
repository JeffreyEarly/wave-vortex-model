---
layout: default
title: transformBack
parent: WVVerticalTransformConstantStratification
grand_parent: Developer internals
nav_order: 7
mathjax: true
---

#  transformBack

Transform `[Nj,Nbatch]` coefficients to `[Nz,Nbatch]` values.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `coefficients`  Real or complex retained coefficients.
+ `transformType`  `"cosine"` or `"sine"`.
+ `fallbackMatrix`  Normalized `[Nz,Nj]` dense matrix.

## Returns
+ `values`  Reconstructed `[Nz,Nbatch]` values.

## Discussion

The fallback matrix must be the existing normalized WV cosine
or sine inverse matrix with shape `[Nz,Nj]`.
