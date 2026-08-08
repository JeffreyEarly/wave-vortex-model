---
layout: default
title: intZF
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 141
mathjax: true
---

#  intZF

Return the first antiderivative of an F-representation.


---

## Declaration
```matlab
 U = intZF(u,n=1)
```
## Parameters
+ `u`  F-representation in `[Nx Ny Nz]` or `[Nz N]` layout
+ `n`  antiderivative order; only 1 is supported (default 1)

## Returns
+ `U`  G-representation antiderivative in the input layout

## Discussion

The result is the antiderivative representable in G space. The
barotropic F mode is removed because it has no corresponding G mode, so
the result vanishes at both vertical boundaries. `u` may use the gridded
layout `[Nx Ny Nz]` or a vertical-first matrix `[Nz N]`; the returned
array preserves that layout.
