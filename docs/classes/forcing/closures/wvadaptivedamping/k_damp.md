---
layout: default
title: k_damp
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 9
mathjax: true
---

#  k_damp

Estimated horizontal wavenumber for significant damping.


---

## Discussion

Units are radians per meter. The filter is already nonzero below
this estimate; use `k_no_damp` for the exact zero-damping cutoff.
