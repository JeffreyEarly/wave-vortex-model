---
layout: default
title: diffZG
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 66
mathjax: true
---

#  diffZG

Differentiate a G-grid field with respect to z.


---

## Declaration
```matlab
 du = diffZG(u,n=n)
```
## Parameters
+ `u`  G-grid field with dimensions `[Nx Ny Nz]`
+ `n`  derivative order from 1 through 4 (default 1)

## Returns
+ `du`  vertical derivative in the alternating G/F representation

## Discussion

`u` must use the gridded layout `[Nx Ny Nz]`. Orders 1 through 4 are
supported. Odd orders return an F-representation and even orders return
a G-representation.
