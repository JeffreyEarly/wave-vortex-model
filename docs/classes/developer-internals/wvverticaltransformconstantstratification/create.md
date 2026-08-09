---
layout: default
title: create
parent: WVVerticalTransformConstantStratification
grand_parent: Developer internals
nav_order: 4
mathjax: true
---

#  create

a vertical strategy for the active model backend.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `Nz`  Number of physical vertical grid points.
+ `Nj`  Number of retained WV vertical modes.
+ `activeBackend`  `"builtin"` or `"fftw"`.

## Returns
+ `strategy`  Configured vertical transform strategy.

## Discussion

Builtin construction performs no FFTW capability query. FFTW
construction queries capabilities once and never attempts a
build; horizontal backend construction owns the build attempt.
