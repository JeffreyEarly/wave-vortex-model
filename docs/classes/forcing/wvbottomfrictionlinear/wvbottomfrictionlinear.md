---
layout: default
title: WVBottomFrictionLinear
parent: WVBottomFrictionLinear
grand_parent: Forcing
nav_order: 1
mathjax: true
---

#  WVBottomFrictionLinear

initialize the WVBottomFrictionLinear


---

## Declaration
```matlab
 self = WVBottomFrictionLinear(wvt,options)
```
## Parameters
+ `wvt`  a WVTransform instance
+ `r`  (optional) linear bottom friction, try 1/(200*86400)

## Returns
+ `frictionalForce`  a WVBottomFrictionLinear instance

## Discussion

See the [WVBottomFrictionLinear overview](/classes/forcing/wvbottomfrictionlinear/)
for the governing equations, resolution scaling, comparison
with quadratic drag, and a usage example.
