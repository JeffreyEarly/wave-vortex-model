---
layout: default
title: transformToPseudoRadialWavenumber
parent: WVTransformBoussinesq
grand_parent: Classes
nav_order: 216
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
 
        
