---
layout: default
title: j_damp
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 10
mathjax: true
---

#  j_damp

Estimated vertical mode number for significant damping.


---

## Discussion

This value is dimensionless. Free-surface QG uses the ordinal APV
family coordinate because its physical labels include a negative
surface mode. The filter is already nonzero below this estimate;
use `j_no_damp` for the exact zero-damping cutoff.
