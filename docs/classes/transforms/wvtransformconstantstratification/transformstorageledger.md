---
layout: default
title: transformStorageLedger
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 277
mathjax: true
---

#  transformStorageLedger

Return known transform storage and explicitly opaque internal storage.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 ledger = transformStorageLedger()
```
## Returns
+ `ledger`  exact application-owned arrays, opaque records, and aggregate byte counts

## Discussion

This hidden benchmark contract excludes canonical model coefficients and
forcing state. It reports transform-owned mappings, buffers, and vertical
matrices exactly while keeping MATLAB-internal FFT storage opaque.
