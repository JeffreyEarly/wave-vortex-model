---
layout: default
title: explicitTimeStepLimit
parent: WVVerticalDiffusivity
grand_parent: Closures
nav_order: 6
mathjax: true
---

#  explicitTimeStepLimit

Return a conservative explicit diffusion timescale in seconds.

> Developer documentation: this item describes internal implementation details.


---

## Returns
+ `deltaT`  inverse largest norm bound, or Inf for zero diffusion

## Discussion

The inverse infinity norm of each generator in well-scaled
physical coordinates bounds the largest eigenvalue magnitude.
This avoids an eigensolve and keeps decaying diffusion modes
inside the RK4 stability region. Positive physical growth is
not clipped, and accuracy may require a smaller step.
