---
layout: default
title: transformFromFourierStorageToWVGrid
parent: WVFourierStorageLayout
grand_parent: Developer internals
nav_order: 22
mathjax: true
---

#  transformFromFourierStorageToWVGrid

Map a Fourier row view to canonical WV-grid ordering.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 wvArray = transformFromFourierStorageToWVGrid(fourierStorageRows)
```
## Parameters
+ `fourierStorageRows`  Fourier row view [nFourierStorageRows,Nbatch]

## Returns
+ `wvArray`  canonical WV-grid coefficients [Nbatch,Nkl]

## Discussion

FourierStorageRows has shape [nFourierStorageRows,Nbatch]. The
returned complex array has shape [Nbatch,Nkl]. Direct modes are
gathered without conjugation; modes outside compressed storage
are recovered through Hermitian conjugation.
