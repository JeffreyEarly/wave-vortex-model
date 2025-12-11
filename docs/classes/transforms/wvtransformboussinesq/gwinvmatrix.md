---
layout: default
title: GwInvMatrix
parent: WVTransformBoussinesq
grand_parent: Classes
nav_order: 16
mathjax: true
---

#  GwInvMatrix

transformation matrix $$G_w^{-1}$$


---

## Declaration
```matlab
 Ginv = GwInvMatrix(wvt,kMode,lMode)
```
## Returns
+ `Ginv`  A matrix with dimensions [Nz Nj]

## Discussion

  A matrix that transforms a vector of igw amplitudes from
  vertical mode space to physical space.
 
      
