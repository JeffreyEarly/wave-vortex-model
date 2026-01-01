---
layout: default
title: WVVerticalDiffusivity
parent: WVVerticalDiffusivity
grand_parent: Classes
nav_order: 1
mathjax: true
---

#  WVVerticalDiffusivity

initialize the WVVerticalDiffusivity


---

## Declaration
```matlab
 self = WVVerticalDiffusivity(wvt,options)
```
## Parameters
+ `wvt`  a WVTransform instance
+ `kappa_z`  (optional) vertical diffusivity, $$m^2s^{-1}$$. Default values 1e-5
+ `shouldForceMeanDensityAnomaly`  (optional) whether to include the $$\frac{\partial}{\partial z} \ln N^2$$ term. Default `true`.

## Returns
+ `self`  a WVVerticalDiffusivity instance

## Discussion

            
