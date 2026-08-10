---
layout: default
title: z_int
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 320
mathjax: true
---

#  z_int

Vertical quadrature weights in meters.


---

## Description
Real valued property with dimension $$z$$ and units of $$m$$.

## Discussion
Vertical quadrature weights in meters.

`z_int` is an `Nz`-by-1 vector used to integrate functions sampled at `z`. The weights satisfy `sum(z_int) = Lz` to quadrature accuracy.
