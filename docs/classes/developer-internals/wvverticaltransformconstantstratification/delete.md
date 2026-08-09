---
layout: default
title: delete
parent: WVVerticalTransformConstantStratification
grand_parent: Developer internals
nav_order: 5
mathjax: true
---

#  delete

every cached FFTW plan idempotently.

> Developer documentation: this item describes internal implementation details.


---

## Discussion

The strategy retains no array-sized MATLAB work buffers. Plan
deletion releases the native FFTW plans owned by the cached
`RealToRealTransform` objects.
