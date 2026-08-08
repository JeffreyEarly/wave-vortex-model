---
layout: default
title: FwInvMatrix
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 17
mathjax: true
---

#  FwInvMatrix

transformation matrix $$F_w^{-1}$$

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 Finv = FwInvMatrix(wvt,kMode,lMode)
```
## Returns
+ `Finv`  A matrix with dimensions [Nz Nj]

## Discussion

A matrix that transforms a vector of igw amplitudes from
vertical mode space to physical space.
