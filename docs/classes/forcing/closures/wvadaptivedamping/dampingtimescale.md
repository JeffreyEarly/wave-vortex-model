---
layout: default
title: dampingTimeScale
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 6
mathjax: true
---

#  dampingTimeScale

Return the inverse maximum unit-speed damping coefficient.


---

## Declaration
```matlab
 dampingTimeScale = dampingTimeScale()
```
## Returns
+ `dampingTimeScale`  inverse maximum absolute entry of `damp`, in meters

## Discussion

Despite the historical method name, this value has units of
meters because `damp` has units of inverse meters. For a
nonzero flow, divide this value by `wvt.uvMax` to obtain the
shortest instantaneous e-folding time in seconds.
