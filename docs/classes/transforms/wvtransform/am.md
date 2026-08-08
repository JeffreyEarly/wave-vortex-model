---
layout: default
title: Am
parent: WVTransform
grand_parent: Transforms
nav_order: 8
mathjax: true
---

#  Am

Negative-frequency wave and inertial coefficients at reference time `t0`.


---

## Discussion

`Am` is a complex array with the transform's spectral layout. Only
locations selected by the primary wave and inertial component masks
are active. Its conjugacy relations with `Ap` enforce a real
physical state, including `Am = conj(Ap)` on inertial modes.
