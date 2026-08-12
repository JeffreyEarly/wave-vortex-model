---
layout: default
title: flowComponents
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 118
mathjax: true
---

#  flowComponents

All registered physical and diagnostic flow components.


---

## Declaration
```matlab
 components = flowComponents()
```
## Returns
+ `components`  array of registered `WVFlowComponent` objects

## Discussion
All registered physical and diagnostic flow components.

The returned `WVFlowComponent` array includes primary components and any additional diagnostic components registered with the transform. Use `flowComponentWithName` for lookup by `shortName`.
