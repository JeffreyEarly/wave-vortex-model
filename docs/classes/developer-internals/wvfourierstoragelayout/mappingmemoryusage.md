---
layout: default
title: mappingMemoryUsage
parent: WVFourierStorageLayout
grand_parent: Developer internals
nav_order: 16
mathjax: true
---

#  mappingMemoryUsage

Return exact memory usage for each mapping array.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 ledger = mappingMemoryUsage()
```
## Returns
+ `ledger`  structure array describing all uint64 mappings

## Discussion

Each entry records name, MATLAB class, shape, and bytes. The sum
of ledger.bytes equals mappingMemoryBytes.
