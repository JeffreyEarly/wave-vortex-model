---
layout: default
title: transformToOmegaAxis
parent: WVTransformStratifiedQG
grand_parent: Classes
nav_order: 157
mathjax: true
---

#  transformToOmegaAxis

transforms in the from (j,kRadial) to omegaAxis


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
 
        
