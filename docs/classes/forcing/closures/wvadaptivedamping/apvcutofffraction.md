---
layout: default
title: apvCutoffFraction
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 2
mathjax: true
---

#  apvCutoffFraction

Fraction of the largest APV mode below which vertical damping is zero.


---

## Type
+ Class: `double`
+ Size: `(1,1)`

## Description
Real valued property with no dimensions and is dimensionless.

## Discussion

Applies to free-surface QG only. A finite value lies in [0,1).
The default NaN retains the standard spectral-vanishing cutoff.
Changing this setting rebuilds the operator and persists on restart.
