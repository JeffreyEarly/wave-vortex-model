---
layout: default
title: primaryFlowComponents
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 211
mathjax: true
---

#  primaryFlowComponents

Primary flow components that partition the active coefficient state.


---

## Declaration
```matlab
 components = primaryFlowComponents
```
## Returns
+ `components`  array of registered `WVPrimaryFlowComponent` objects

## Discussion
Primary flow components that partition the active coefficient state.

Each returned `WVPrimaryFlowComponent` owns disjoint coefficient masks and contributes modes to `totalFlowComponent`.
