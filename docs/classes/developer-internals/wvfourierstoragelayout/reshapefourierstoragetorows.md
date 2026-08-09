---
layout: default
title: reshapeFourierStorageToRows
parent: WVFourierStorageLayout
grand_parent: Developer internals
nav_order: 21
mathjax: true
---

#  reshapeFourierStorageToRows

Reshape natural Fourier storage to its two-dimensional row view.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 fourierStorageRows = reshapeFourierStorageToRows(fourierStorage)
```
## Parameters
+ `fourierStorage`  natural Fourier storage [NxStorage,NyStorage,...]

## Returns
+ `fourierStorageRows`  row view [nFourierStorageRows,Nbatch]

## Discussion

FourierStorage must begin with fourierStorageSize. All remaining
dimensions are combined as Nbatch. Reshape does not reorder data.
