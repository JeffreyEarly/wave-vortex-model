---
layout: default
title: coefficientState
parent: WVTransform
grand_parent: Transforms
nav_order: 23
mathjax: true
---

#  coefficientState

Copy the canonical coefficient families, optionally selecting a component.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 state = coefficientState(options)
```
## Parameters
+ `options.flowComponent`  selector belonging to this transform; empty selects the full state

## Returns
+ `state`  scalar structure keyed in coefficient-annotation order

## Discussion

Arrays retain their independent shapes, numeric domains, and reference
time. Selection does not advance wave phases or mutate the transform.
