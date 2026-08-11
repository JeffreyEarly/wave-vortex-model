---
layout: default
title: GMatrix
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 18
mathjax: true
---

#  GMatrix

Transformation matrix $$G$$ projecting G-grid values onto vertical modes; shape `[Nj Nz]`.


---

## Description
Real valued property with dimensions $$(j,z)$$ and is dimensionless.

## Discussion
Transformation matrix $$G$$ projecting G-grid values onto vertical modes; shape `[Nj Nz]`.

`GMatrix` maps a column sampled on the physical vertical grid into coefficients of the G vertical-mode basis.
