---
layout: default
title: allocateFourierStorage
parent: WVFourierStorageLayout
grand_parent: Developer internals
nav_order: 3
mathjax: true
---

#  allocateFourierStorage

Allocate a zeroed complex Fourier row view.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 fourierStorageRows = allocateFourierStorage(nBatch)
```
## Parameters
+ `nBatch`  positive number of independent transform batches

## Returns
+ `fourierStorageRows`  zeroed complex Fourier row view

## Discussion

The returned array has shape [nFourierStorageRows,Nbatch]. Use
reshapeFourierRowsToStorage when an FFT backend needs the natural
[NxStorage,NyStorage,Nbatch] shape.
