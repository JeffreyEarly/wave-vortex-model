---
layout: default
title: transformToPseudoRadialWavenumberApm
parent: WVTransformStratifiedQG
grand_parent: Classes
nav_order: 160
mathjax: true
---

#  transformToPseudoRadialWavenumberApm

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
 
        
