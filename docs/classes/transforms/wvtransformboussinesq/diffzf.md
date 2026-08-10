---
layout: default
title: diffZF
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 110
mathjax: true
---

#  diffZF

Differentiate an F-grid field with respect to z.


---

## Declaration
```matlab
 du = diffZF(u,n=n)
```
## Parameters
+ `u`  F-grid field with dimensions `[Nx Ny Nz]`
+ `n`  derivative order from 1 through 4 (default 1)

## Returns
+ `du`  vertical derivative in the alternating F/G representation

## Discussion

`u` must use the gridded layout `[Nx Ny Nz]`. Orders 1 through 4 are
supported. Odd orders return a G-representation and even orders return
an F-representation.
