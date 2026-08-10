---
layout: default
title: transformFromSpatialDomainToDFTGrid
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 259
mathjax: true
---

#  transformFromSpatialDomainToDFTGrid

transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 u_bar = transformFromSpatialDomainToDFTGrid(u)
```
## Parameters
+ `u`  a real-valued matrix of size [Nx Ny Nz]

## Returns
+ `u_bar`  a complex-valued matrix of size [Nk_dft Nl_dft Nz]

## Discussion

Performs a Fourier transform in the x and y direction. The
resulting matrix is on the DFT grid.
