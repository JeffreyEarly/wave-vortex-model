---
layout: default
title: transformFromWVGridToFourierStorage
parent: WVFourierStorageLayout
grand_parent: Developer internals
nav_order: 23
mathjax: true
---

#  transformFromWVGridToFourierStorage

Insert WV-grid coefficients into caller-owned Fourier storage.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 fourierStorageRows = transformFromWVGridToFourierStorage(fourierStorageRows,wvArray)
```
## Parameters
+ `fourierStorageRows`  caller-owned Fourier row view [nFourierStorageRows,Nbatch]
+ `wvArray`  canonical WV-grid coefficients [Nbatch,Nkl]

## Returns
+ `fourierStorageRows`  updated Fourier row view; always reassign this value

## Discussion

The first input is a caller-owned row view with shape
[nFourierStorageRows,Nbatch]. WVArray has shape [Nbatch,Nkl].
Direct and conjugated mappings are inserted, required Hermitian
boundary rows are completed, and self-conjugate rows are made
real. MATLAB may detach a shared input through copy-on-write, so
callers must capture and reassign the returned storage:

  rows = layout.transformFromWVGridToFourierStorage(rows,wvArray);
