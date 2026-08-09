---
layout: default
title: transformToPseudoRadialWavenumber
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 221
mathjax: true
---

#  transformToPseudoRadialWavenumber

transforms in the from (j,kRadial) to kPseudoRadial


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
