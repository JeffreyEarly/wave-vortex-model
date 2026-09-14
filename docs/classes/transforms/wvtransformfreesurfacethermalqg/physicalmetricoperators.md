---
layout: default
title: physicalMetricOperators
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 168
mathjax: true
---

#  physicalMetricOperators

Build physical quadrature maps and full quadratic metrics from stored arrays.

> Developer documentation: this item describes internal implementation details.


---

## Returns
+ `operators`  quadrature, reconstruction maps, factors and Gram matrices

## Discussion

Thermal pages retain all cross terms. Their factors map Ath to weighted
physical fields; contractions use these factors to avoid squaring the
conditioning of nearly cancelling source or null directions. Energy uses
total displacement, while physical buoyancy uses interior displacement.
MDA maps interpolate the authoritative native arrays in their WKB coordinate.
These immutable caches require no scientific mode solve and are not saved.
