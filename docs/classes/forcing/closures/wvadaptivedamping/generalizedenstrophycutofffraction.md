---
layout: default
title: generalizedEnstrophyCutoffFraction
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 13
mathjax: true
---

#  generalizedEnstrophyCutoffFraction

Fraction of the ordered native generalized spectrum left undamped.

> Developer documentation: this item describes internal implementation details.


---

## Type
+ Class: `double`
+ Size: `(1,1)`

## Description
Real valued property with no dimensions and is dimensionless.

## Discussion

Applies only to the native thermal closure. A finite value lies in
[0,1); NaN selects the standard spectral-vanishing cutoff.
Changing this value rebuilds only the transient application cache.
