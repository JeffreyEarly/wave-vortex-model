---
layout: default
title: WVNonlinearAdvection
parent: WVNonlinearAdvection
grand_parent: Forcing
nav_order: 1
mathjax: true
---

#  WVNonlinearAdvection

Create nonlinear advection for a transform.


---

## Declaration
```matlab
 self = WVNonlinearAdvection(wvt)
```
## Parameters
+ `wvt`  transform that owns and evaluates the forcing

## Returns
+ `self`  nonlinear-advection forcing owned by `wvt`

## Discussion

See the [WVNonlinearAdvection overview](/classes/forcing/wvnonlinearadvection/)
for the hydrostatic, nonhydrostatic, and QGPV equations and
its role as the default forcing.
