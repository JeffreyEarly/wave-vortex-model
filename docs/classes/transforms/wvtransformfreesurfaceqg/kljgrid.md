---
layout: default
title: kljGrid
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 133
mathjax: true
---

#  kljGrid

Return spectral-coordinate arrays in wave-vortex layout.


---

## Declaration
```matlab
 [K,L,J] = kljGrid()
```
## Returns
+ `K`  x-direction angular wavenumbers in radians per meter
+ `L`  y-direction angular wavenumbers in radians per meter
+ `J`  dimensionless vertical-mode indices

## Discussion
Return spectral-coordinate arrays in wave-vortex layout.

`[K,L,J] = wvt.kljGrid` returns arrays with `wvt.spectralMatrixSize`. `K` and `L` contain angular wavenumbers in radians per meter, and `J` contains dimensionless vertical-mode indices.

```matlab
[K,L,J] = wvt.kljGrid;
```
