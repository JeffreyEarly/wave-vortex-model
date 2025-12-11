---
layout: default
title: transformToSpatialDomainFromDFTGrid
parent: WVTransformStratifiedQG
grand_parent: Classes
nav_order: 162
mathjax: true
---

#  transformToSpatialDomainFromDFTGrid

transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$


---

## Declaration
```matlab
 u = transformToSpatialDomainFromDFTGrid(u_bar)  
```
## Parameters
+ `u_bar`  a complex-valued matrix of size [Nk_dft Nl_dft Nz]

## Returns
+ `u`  a real-valued matrix of size [Nx Ny Nz]

## Discussion

  Performs an inverse Fourier transform to take a matrix from
  the DFT grid back to the spatial domain.
 
        
