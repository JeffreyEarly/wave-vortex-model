---
layout: default
title: WVModel
parent: WVModel
grand_parent: Class documentation
nav_order: 1
mathjax: true
---

#  WVModel

Initialize a model from a WVTransform instance.


---

## Declaration
```matlab
 model = WVModel(wvt,options)
```
## Parameters
+ `wvt`  `WVTransform` instance representing the initial fluid state
+ `options.shouldUseLinearDynamics`  use analytical linear evolution; default `false`

## Returns
+ `model`  new `WVModel` instance

## Discussion
