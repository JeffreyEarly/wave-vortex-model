---
layout: default
title: plus
parent: WVFlowComponent
grand_parent: Flow components
nav_order: 11
mathjax: true
---

#  plus

Form the union of two selections on the same transform.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 h = plus(f,g)
```
## Parameters
+ `f`  first selector
+ `g`  second selector on the same transform

## Returns
+ `h`  component selecting the union of both masks

## Discussion

Overlapping modes are selected once. Energies of the two
components are not assumed to be additive.
