---
layout: default
title: WVFlowComponent
parent: WVFlowComponent
grand_parent: Flow components
nav_order: 1
mathjax: true
---

#  WVFlowComponent

Create a selector for resolved coefficient families.


---

## Declaration
```matlab
 solnGroup = WVFlowComponent(wvt,options)
```
## Parameters
+ `wvt`  instance of a WVTransform
+ `options.coefficientMasks`  family-keyed scalar structure; omitted families select zero
+ `options.maskAp`  legacy positive-wave selector
+ `options.maskAm`  legacy negative-wave selector
+ `options.maskA0`  legacy zero-frequency selector

## Returns
+ `solnGroup`  resolved coefficient selector

## Discussion

Supply scalar zero/one or exact family-shaped masks through
`coefficientMasks`. New-family masks are fixed at construction.
Masks must preserve the concrete model's conjugate symmetries.
