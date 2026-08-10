---
layout: default
title: initWithUVRho
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 145
mathjax: true
---

#  initWithUVRho

initialize with fluid variables $$(u,v,\rho)$$


---

## Declaration
```matlab
 initWithUVRho(U,V,RHO)
```
## Parameters
+ `u`  x-component of the fluid velocity
+ `v`  y-component of the fluid velocity
+ `rho`  density anomaly

## Discussion

Replaces the variables Ap,Am,A0 with those computed from $$(u,v,\rho_e)$$.
