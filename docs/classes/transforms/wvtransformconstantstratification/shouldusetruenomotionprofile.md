---
layout: default
title: shouldUseTrueNoMotionProfile
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 245
mathjax: true
---

#  shouldUseTrueNoMotionProfile

Whether displacement uses the diagnosed current no-motion profile.


---

## Type
+ Class: `logical`
+ Size: `(1,1)`

## Discussion
Whether displacement uses the diagnosed current no-motion profile.

The default is `false`, which computes `eta_true` using the original reference profile `rho_nm0`. Set this property to `true` to use the diagnosed `rho_nm` instead. The reference-profile path is an approximation when the current density distribution differs from the initial distribution.

Changing the flag invalidates cached `rho_nm`, `eta_true`, `ape`, and `apv`. The flag is preserved by transform copies but remains runtime-only: loading a saved transform restores the default.
