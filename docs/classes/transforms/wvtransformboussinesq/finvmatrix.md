---
layout: default
title: FinvMatrix
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 17
mathjax: true
---

#  FinvMatrix

Transformation matrix $$F^{-1}$$ reconstructing F-grid values from vertical modes; shape `[Nz Nj]`.


---

## Description
Real valued property with dimensions $$(z,j)$$ and no units.

## Discussion
Transformation matrix $$F^{-1}$$ reconstructing F-grid values from vertical modes; shape `[Nz Nj]`.

`FinvMatrix` maps F-basis modal coefficients back to values on the physical vertical grid.
