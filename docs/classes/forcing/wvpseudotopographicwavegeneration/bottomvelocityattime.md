---
layout: default
title: bottomVelocityAtTime
parent: WVPseudoTopographicWaveGeneration
grand_parent: Forcing
nav_order: 5
mathjax: true
---

#  bottomVelocityAtTime

Evaluate the bottom kinematic velocity.


---

## Declaration
```matlab
 gBottom = bottomVelocityAtTime(t)
```
## Parameters
+ `t`  finite scalar time in seconds

## Returns
+ `gBottom`  real bottom-normal velocity on the horizontal grid

## Discussion

For upward-positive topography, this returns
$$g_b=\mathbf{U}_{\mathrm{bt}}\cdot\nabla_H h$$.
