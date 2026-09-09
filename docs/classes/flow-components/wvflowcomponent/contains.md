---
layout: default
title: contains
parent: WVFlowComponent
grand_parent: Flow components
nav_order: 4
mathjax: true
---

#  contains

Test containment of selections in the same resolved state.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 bool = contains(otherComponent)
```
## Parameters
+ `otherComponent`  selector belonging to the same transform

## Returns
+ `bool`  true when every selected coefficient is contained

## Discussion

Physically empty families contribute no selected modes.
