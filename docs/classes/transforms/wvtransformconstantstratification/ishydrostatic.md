---
layout: default
title: isHydrostatic
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 159
mathjax: true
---

#  isHydrostatic

Whether the transform uses the hydrostatic approximation.


---

## Description
Real valued property with no dimensions and is dimensionless.

## Discussion
Whether the transform uses the hydrostatic approximation.

This value is `true` for `WVTransformHydrostatic`, `WVTransformStratifiedQG`, and `WVTransformBarotropicQG`, and `false` for `WVTransformBoussinesq`. `WVTransformConstantStratification` takes the value from its `isHydrostatic` constructor option, whose default is `false`.
