---
layout: default
title: transformForward
parent: WVVerticalTransformConstantStratification
grand_parent: Developer internals
nav_order: 8
mathjax: true
---

#  transformForward

Transform `[Nz,Nbatch]` values to `[Nj,Nbatch]` coefficients.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `values`  Real or complex `[Nz,Nbatch]` values.
+ `transformType`  `"cosine"` or `"sine"`.
+ `fallbackMatrix`  Normalized `[Nj,Nz]` dense matrix.

## Returns
+ `coefficients`  Retained `[Nj,Nbatch]` coefficients.

## Discussion

The fallback matrix must be the existing normalized WV cosine
or sine forward matrix with shape `[Nj,Nz]`.
