---
layout: default
title: WVBottomFrictionLinear
parent: WVBottomFrictionLinear
grand_parent: Forcing
nav_order: 1
mathjax: true
---

#  WVBottomFrictionLinear

Create linear bottom friction for a transform.


---

## Declaration
```matlab
 self = WVBottomFrictionLinear(wvt,options)
```
## Parameters
+ `wvt`  transform that owns and evaluates the forcing
+ `r`  optional drag rate in inverse seconds; default `1/(200*86400)`

## Returns
+ `self`  linear bottom-friction forcing owned by `wvt`

## Discussion

See the [WVBottomFrictionLinear overview](/classes/forcing/wvbottomfrictionlinear/)
for the governing equations, resolution scaling, comparison
with quadratic drag, and a usage example.
