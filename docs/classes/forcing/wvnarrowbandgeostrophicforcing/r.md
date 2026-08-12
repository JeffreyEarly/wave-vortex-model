---
layout: default
title: r
parent: WVNarrowBandGeostrophicForcing
grand_parent: Forcing
nav_order: 14
mathjax: true
---

#  r

Effective large-scale damping rate in inverse seconds.


---

## Type
+ Class: `double`
+ Size: `(1,1)`

## Description
Real valued property with no dimensions and units of $$\mathrm{s^{-1}}$$.

## Discussion

When supplied, `r` determines `k_r`. When omitted, it is derived
from `k_r`, `u_rms`, and the transform-specific surface scaling.
