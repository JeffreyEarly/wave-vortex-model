---
layout: default
title: intZG
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 140
mathjax: true
---

#  intZG

Return the bottom-zero first antiderivative of a G-representation.


---

## Declaration
```matlab
 W = intZG(w,n=1)
```
## Parameters
+ `w`  G-representation in `[Nx Ny Nz]` or `[Nz N]` layout
+ `n`  antiderivative order; only 1 is supported (default 1)

## Returns
+ `W`  bottom-zero F-representation antiderivative in the input layout

## Discussion

A G-to-F antiderivative is defined up to an additive constant. This
method selects the representative that vanishes at the bottom boundary.
`w` may use the gridded layout `[Nx Ny Nz]` or a vertical-first matrix
`[Nz N]`; the returned array preserves that layout.
