---
layout: default
title: fourierRowsForConjugatedWVIndices
parent: WVFourierStorageLayout
grand_parent: Developer internals
nav_order: 8
mathjax: true
---

#  fourierRowsForConjugatedWVIndices

Fourier rows conjugated while recovering the corresponding WV modes.

> Developer documentation: this item describes internal implementation details.


---

## Type
+ Class: `uint64`

## Discussion
These occur when a requested WV mode lies outside Hermitian-half
storage in the compressed direction.
