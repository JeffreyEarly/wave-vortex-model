---
layout: default
title: coefficientDampingData
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 6
mathjax: true
---

#  coefficientDampingData

Materialize native thermal radius operators and construction diagnostics.

> Developer documentation: this item describes internal implementation details.


---

## Discussion

Normal forcing evaluation uses the private batched operators.
This inspection view reconstructs the per-radius matrices on
request. executionCacheBytes reports retained application data,
excluding these additional caller-owned inspection copies.
