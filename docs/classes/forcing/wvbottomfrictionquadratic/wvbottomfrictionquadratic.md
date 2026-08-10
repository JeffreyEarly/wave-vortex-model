---
layout: default
title: WVBottomFrictionQuadratic
parent: WVBottomFrictionQuadratic
grand_parent: Forcing
nav_order: 2
mathjax: true
---

#  WVBottomFrictionQuadratic

initialize the WVBottomFrictionQuadratic


---

## Declaration
```matlab
 self = WVBottomFrictionQuadratic(wvt,options)
```
## Parameters
+ `wvt`  a WVTransform instance
+ `Cd`  (optional) non-dimensional quadratic damping coefficient. Default is 0.001

## Returns
+ `frictionalForce`  a WVBottomFrictionQuadratic instance

## Discussion

See the [WVBottomFrictionQuadratic overview](/classes/forcing/wvbottomfrictionquadratic/)
for the governing equations, geometry-dependent scaling,
comparison with linear drag, and a usage example.
