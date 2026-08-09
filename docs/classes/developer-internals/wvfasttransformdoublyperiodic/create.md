---
layout: default
title: create
parent: WVFastTransformDoublyPeriodic
grand_parent: Developer internals
nav_order: 3
mathjax: true
---

#  create

Construct the requested backend or a safe builtin fallback.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `geometry`  completed doubly periodic WV geometry
+ `Nz`  number of horizontal-transform batches
+ `requestedBackend`  `"builtin"` or `"fftw"`

## Returns
+ `adapter`  selected `WVFastTransformDoublyPeriodic`
+ `selection`  structured selection and fallback record

## Discussion

The canonical geometry and WV coefficient ordering must be
complete before calling this method. Backend selection changes
only Fourier storage and execution; it does not change the WV
grid. The returned selection record reports the requested and
active backends, fallback and build status, provider/library
identity, and any structured failure reason.
