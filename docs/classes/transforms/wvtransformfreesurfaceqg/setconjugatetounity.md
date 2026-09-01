---
layout: default
title: setConjugateToUnity
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 194
mathjax: true
---

#  setConjugateToUnity

set the conjugate of the wavenumber (iK,iL) to 1

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 matrix = WVGeometryDoublyPeriodic.indexOfFourierConjugate(Nx,Ny,Nz);
```
## Parameters
+ `Nx`  grid points in the x-direction
+ `Ny`  grid points in the y-direction
+ `Nz`  grid points in the z-direction (defuault 1)

## Returns
+ `matrix`  matrix containing linear indices

## Discussion
