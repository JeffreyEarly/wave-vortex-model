---
layout: default
title: reshapeFourierRowsToStorage
parent: WVFourierStorageLayout
grand_parent: Developer internals
nav_order: 20
mathjax: true
---

#  reshapeFourierRowsToStorage

Reshape a row view to natural Fourier-storage dimensions.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 fourierStorage = reshapeFourierRowsToStorage(fourierStorageRows)
```
## Parameters
+ `fourierStorageRows`  Fourier row view [nFourierStorageRows,Nbatch]

## Returns
+ `fourierStorage`  natural storage [NxStorage,NyStorage,Nbatch]

## Discussion
