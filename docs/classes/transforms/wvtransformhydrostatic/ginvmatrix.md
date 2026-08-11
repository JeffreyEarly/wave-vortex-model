---
layout: default
title: GinvMatrix
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 19
mathjax: true
---

#  GinvMatrix

Transformation matrix $$G^{-1}$$ reconstructing G-grid values from vertical modes; shape `[Nz Nj]`.


---

## Description
Real valued property with dimensions $$(z,j)$$ and is dimensionless.

## Discussion
Transformation matrix $$G^{-1}$$ reconstructing G-grid values from vertical modes; shape `[Nz Nj]`.

`GinvMatrix` maps G-basis modal coefficients back to values on the physical vertical grid.
