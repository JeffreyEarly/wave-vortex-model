---
layout: default
title: eta_i
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 87
mathjax: true
---

#  eta_i

Interior displacement on the fixed reference grid, including MDA.

> Developer documentation: this item describes internal implementation details.


---

## Discussion

Subtract the surface lift from total displacement:
$$\eta_i = \eta - (1 + z/L_z)\,\mathrm{ssh}.$$
Here `z` is reference depth; this diagnostic does not change the
small-surface-amplitude QG evolution.
