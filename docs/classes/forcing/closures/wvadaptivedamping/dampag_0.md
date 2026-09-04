---
layout: default
title: dampAg_0
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 7
mathjax: true
---

#  dampAg_0

Unit-speed damping operator for free-surface zero-APV coefficients.

> Developer documentation: this item describes internal implementation details.


---

## Discussion

This array has the shape of `wvt.Ag_0` for a
`WVTransformFreeSurfaceQG` and is empty for other transforms. The
endpoint family is damped horizontally because its rows identify
active boundaries rather than an ordered vertical-mode family.
