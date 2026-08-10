---
layout: default
title: WVBottomFrictionQuadratic
parent: WVBottomFrictionQuadratic
grand_parent: Forcing
nav_order: 2
mathjax: true
---

#  WVBottomFrictionQuadratic

Create quadratic bottom friction for a transform.


---

## Declaration
```matlab
 self = WVBottomFrictionQuadratic(wvt,options)
```
## Parameters
+ `wvt`  transform that owns and evaluates the forcing
+ `Cd`  optional dimensionless drag coefficient; default `1e-3`

## Returns
+ `self`  quadratic bottom-friction forcing owned by `wvt`

## Discussion

See the [WVBottomFrictionQuadratic overview](/classes/forcing/wvbottomfrictionquadratic/)
for the governing equations, geometry-dependent scaling,
comparison with linear drag, and a usage example.
