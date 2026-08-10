---
layout: default
title: transformToOmegaAxis
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 285
mathjax: true
---

#  transformToOmegaAxis

transforms in the from (j,kRadial) to omegaAxis

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [varargout] = transformToRadialWavenumber(varargin)
```
## Parameters
+ `varargin`  variables with dimensions $$(j,kl)$$

## Returns
+ `varargout`  variables with dimensions $$(kRadial)$$ or $$(kRadial,j)$$

## Discussion

Sums all the variance/energy in radial bins `kPseudoRadial`.
