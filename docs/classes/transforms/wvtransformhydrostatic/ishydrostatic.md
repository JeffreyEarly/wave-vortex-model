---
layout: default
title: isHydrostatic
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 151
mathjax: true
---

#  isHydrostatic

Whether the transform uses the hydrostatic approximation.


---

## Discussion
Whether the transform uses the hydrostatic approximation.

This value is `true` for `WVTransformHydrostatic`, `WVTransformStratifiedQG`, and `WVTransformBarotropicQG`, and `false` for `WVTransformBoussinesq`. `WVTransformConstantStratification` takes the value from its `isHydrostatic` constructor option, whose default is `false`.
