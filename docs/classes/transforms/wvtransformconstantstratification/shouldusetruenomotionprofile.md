---
layout: default
title: shouldUseTrueNoMotionProfile
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 246
mathjax: true
---

#  shouldUseTrueNoMotionProfile

Whether density diagnostics use the supplied no-motion profile directly.


---

## Type
+ Class: `logical`
+ Size: `(1,1)`

## Discussion
Whether density diagnostics use the supplied no-motion profile directly.

The default is `false`, which uses the transform-consistent reconstructed profile. Set this property to `true` when diagnostics should evaluate the original `rhoFunction` profile instead.
