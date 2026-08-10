---
layout: default
title: hermitianSourceWVIndices
parent: WVFourierStorageLayout
grand_parent: Developer internals
nav_order: 13
mathjax: true
---

#  hermitianSourceWVIndices

WV-grid indices corresponding to hermitianSourceRows.

> Developer documentation: this item describes internal implementation details.


---

## Type
+ Class: `uint64`

## Discussion
This lets a measured backend write completion rows directly from the
WV grid without first reading a Fourier row.
