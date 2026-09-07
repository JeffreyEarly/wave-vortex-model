---
layout: default
title: reconstructFields
parent: WVTransform
grand_parent: Transforms
nav_order: 73
mathjax: true
---

#  reconstructFields

Reconstruct named physical fields at the current transform time.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 fields = reconstructFields(variableNames,options)
```
## Parameters
+ `variableNames`  row of supported physical field names
+ `options.flowComponent`  one component of this transform; empty selects the full state

## Returns
+ `fields`  scalar structure of physical arrays keyed by requested name

## Discussion

The default implementation uses the existing model-specific operation
factory, including optimized wave and balanced reconstruction paths.
This call computes fields directly without changing coefficient state.
