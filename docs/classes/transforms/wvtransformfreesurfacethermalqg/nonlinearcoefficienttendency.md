---
layout: default
title: nonlinearCoefficientTendency
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 162
mathjax: true
---

#  nonlinearCoefficientTendency

Evaluate complete interior and both-endpoint Jacobians on product quadrature.

> Developer documentation: this item describes internal implementation details.


---

## Returns
+ `tendency`  retained family rates, without diffusion or external forcing
+ `speed`  maximum horizontal speed on the product grid and endpoints
+ `diagnostics`  bounded RHS timings and scratch estimate
