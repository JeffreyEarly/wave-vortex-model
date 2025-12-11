---
layout: default
title: verticalProjectionOperatorsWithRigidLid
parent: WVTransformConstantStratification
grand_parent: Classes
nav_order: 214
mathjax: true
---

#  verticalProjectionOperatorsWithRigidLid

return the normalized projection operators with prefactors


---

## Declaration
```matlab
 [P,Q,PFinv,PF,QGinv,QG,h,w] = WVStratification.verticalProjectionOperatorsWithRigidLid(Finv,Ginv,h,Nj,Lz)
```
## Returns
+ `P`  preconditioner for F, size(P)=[Nj 1]
+ `Q`  preconditioner for Q, size(Q)=[Nj 1]
+ `PFinv`  normalized Finv, size(PFinv)=[Nz x Nj]
+ `PF`  normalized F, size(PF)=[Nj x Nz]
+ `QGinv`  normalized QGinv, size(QGinv)=[Nz x Nj]
+ `QG`  normalized G, size(QG)=[Nj x Nz]
+ `h`  eigenvalue, size(h)=[Nj x 1]
+ `w`  eigenvalue, size(h)=[Nj x 1]

## Discussion

  This function uses InternalModesWKBSpectral to compute the
  quadrature points of a given stratification profile.
 
                    
