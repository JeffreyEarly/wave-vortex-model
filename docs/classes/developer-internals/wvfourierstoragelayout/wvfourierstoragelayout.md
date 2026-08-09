---
layout: default
title: WVFourierStorageLayout
parent: WVFourierStorageLayout
grand_parent: Developer internals
nav_order: 2
mathjax: true
---

#  WVFourierStorageLayout

Create a Fourier-storage mapping for a doubly periodic geometry.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 layout = WVFourierStorageLayout(wvg,fourierStorageType,options)
```
## Parameters
+ `wvg`  WVGeometryDoublyPeriodic defining horizontal modes and WV ordering
+ `fourierStorageType`  "full-complex" or "hermitian-half"
+ `options.compressedDimension`  [], 1, or 2 as required by the storage type

## Returns
+ `layout`  read-only WVFourierStorageLayout

## Discussion

Full-complex storage requires compressedDimension=[]. A
Hermitian-half layout requires compressedDimension=1 (half-x) or
compressedDimension=2 (half-y).
