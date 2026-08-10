---
layout: default
title: effectiveHorizontalGridResolution
parent: WVAntialiasing
grand_parent: Closures
nav_order: 5
mathjax: true
---

#  effectiveHorizontalGridResolution

Return the shortest fully retained horizontal wavelength.


---

## Declaration
```matlab
 effectiveHorizontalGridResolution = effectiveHorizontalGridResolution()
```
## Returns
+ `effectiveHorizontalGridResolution`  effective horizontal resolution in meters

## Discussion

The effective grid resolution is the highest fully resolved
wavelength in the model. This value takes into account
anti-aliasing, and is thus appropriate for setting damping
operators.
