---
layout: default
title: WVAdaptiveDamping
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 1
mathjax: true
---

#  WVAdaptiveDamping

Create adaptive spectral damping for a transform.


---

## Declaration
```matlab
 self = WVAdaptiveDamping(wvt,options)
```
## Parameters
+ `wvt`  transform that owns and evaluates the closure
+ `options.apvCutoffFraction`  optional free-surface APV cutoff fraction; NaN uses the standard cutoff

## Returns
+ `self`  adaptive-damping closure owned by `wvt`

## Discussion
