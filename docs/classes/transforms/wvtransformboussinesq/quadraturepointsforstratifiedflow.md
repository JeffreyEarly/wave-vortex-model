---
layout: default
title: quadraturePointsForStratifiedFlow
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 221
mathjax: true
---

#  quadraturePointsForStratifiedFlow

return the quadrature points for a given stratification

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 z = WVStratification.quadraturePointsForStratifiedFlow()
```
## Returns
+ `z`  array of Nz points

## Discussion

This function uses InternalModesWKBSpectral to compute the
quadrature points of a given stratification profile.
