---
layout: default
title: expandedLegacyMappings
parent: WVFourierStorageLayout
grand_parent: Developer internals
nav_order: 7
mathjax: true
---

#  expandedLegacyMappings

Materialize the vertically expanded legacy full-storage mappings.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [dftPrimaryIndex,dftConjugateIndex,wvConjugateIndex] = expandedLegacyMappings(nBatch)
```
## Parameters
+ `nBatch`  positive batch count used to expand row indices

## Returns
+ `dftPrimaryIndex`  vertically expanded direct Fourier indices
+ `dftConjugateIndex`  vertically expanded Hermitian destination indices
+ `wvConjugateIndex`  vertically expanded WV source indices

## Discussion

This temporary compatibility method exists only until issue #71
removes consumers of the old Nz-replicated geometry properties.
It is unavailable when conjugated extraction is needed.
