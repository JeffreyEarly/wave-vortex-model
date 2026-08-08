---
layout: default
title: WVObservingSystem
parent: WVObservingSystem
grand_parent: Observing systems
nav_order: 1
mathjax: true
---

#  WVObservingSystem

Initialize an observing system for a model.


---

## Declaration
```matlab
 self = WVObservingSystem(model,name)
```
## Parameters
+ `model`  the WVModel instance
+ `name`  name of the observing system

## Returns
+ `self`  a new instance of WVObservingSystem

## Discussion

This class is intended to be subclassed, so it generally
assumed that this initialization will not be called directly.
