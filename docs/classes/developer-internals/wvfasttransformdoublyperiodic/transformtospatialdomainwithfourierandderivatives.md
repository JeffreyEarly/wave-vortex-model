---
layout: default
title: transformToSpatialDomainWithFourierAndDerivatives
parent: WVFastTransformDoublyPeriodic
grand_parent: Developer internals
nav_order: 9
mathjax: true
---

#  transformToSpatialDomainWithFourierAndDerivatives

Reconstruct a field and its first horizontal derivatives.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `uBar`  normalized canonical WV-grid coefficients

## Returns
+ `u`  reconstructed spatial field
+ `u_x`  first derivative with respect to x
+ `u_y`  first derivative with respect to y

## Discussion

Concrete adapters may override this layout-neutral composition
to reuse storage or transform work.
