---
layout: default
title: initWithUVEta
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 144
mathjax: true
---

#  initWithUVEta

initialize with fluid variables $$(u,v,\eta)$$


---

## Declaration
```matlab
 initWithUVEta(U,V,N)
```
## Parameters
+ `u`  x-component of the fluid velocity
+ `v`  y-component of the fluid velocity
+ `n`  scaled density anomaly

## Discussion

Replaces the variables Ap,Am,A0 with those computed from $$(u,v,\eta)$$.
