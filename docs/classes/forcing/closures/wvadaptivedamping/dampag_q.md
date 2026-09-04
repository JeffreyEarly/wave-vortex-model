---
layout: default
title: dampAg_q
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 8
mathjax: true
---

#  dampAg_q

Unit-speed damping operator for free-surface APV coefficients.

> Developer documentation: this item describes internal implementation details.


---

## Discussion

This array has the shape of `wvt.Ag_q` for a
`WVTransformFreeSurfaceQG` and is empty for other transforms. It
combines horizontal and APV-mode spectral-vanishing damping.
