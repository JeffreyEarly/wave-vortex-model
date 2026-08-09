---
layout: default
title: create
parent: WVFastTransformDoublyPeriodicFactory
grand_parent: Developer internals
nav_order: 2
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
