---
layout: default
title: shouldUseTrueNoMotionProfile
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 233
mathjax: true
---

#  shouldUseTrueNoMotionProfile

Whether density diagnostics use the diagnosed current no-motion profile.


---

## Type
+ Class: `logical`
+ Size: `(1,1)`

## Discussion
Whether density diagnostics use the diagnosed current no-motion profile.

The default is `true`: `eta_true`, `ape`, and `apv` use the diagnosed `rho_nm` for the current density distribution. Displacement inverts a monotone cubic representation of that profile, and APE integrates the same representation. The default no-motion solver does not require Optimization Toolbox.

Set this property to `false` to use `rho_nm0` explicitly as an approximation in both displacement and APE. APV uses the resulting displacement. This approximation is appropriate only when the original reference represents the current density distribution; densities outside its range are rejected. The corrected interpolation and APE calculation also apply in this mode, so it does not reproduce the old numerical algorithm exactly.

Changing the flag invalidates cached `rho_nm`, `eta_true`, `ape`, and `apv`. Transform copies preserve the flag. It remains runtime-only: loading an existing or newly saved transform restores the default `true`, without changing the saved-file schema. Recomputed density diagnostics therefore use the corrected default even for older restart files.
