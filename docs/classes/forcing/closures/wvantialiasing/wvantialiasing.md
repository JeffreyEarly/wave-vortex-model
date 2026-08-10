---
layout: default
title: WVAntialiasing
parent: WVAntialiasing
grand_parent: Closures
nav_order: 3
mathjax: true
---

#  WVAntialiasing

Create explicit antialias filtering for a transform.


---

## Declaration
```matlab
 self = WVAntialiasing(wvt,options)
```
## Parameters
+ `wvt`  transform that owns and evaluates the closure
+ `Nj`  optional number of retained vertical modes; modes with `j >= Nj` are discarded; default `floor(2*wvt.Nj/3)`

## Returns
+ `self`  explicit-antialiasing closure owned by `wvt`

## Discussion

The transform must have been constructed with
`shouldAntialias=false`.
