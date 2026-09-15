---
layout: default
title: totalEnergyOfFlowComponent
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 223
mathjax: true
---

#  totalEnergyOfFlowComponent

Evaluate the physical energy of a selected resolved QG state.


---

## Declaration
```matlab
 energy = totalEnergyOfFlowComponent(flowComponent)
```
## Parameters
+ `flowComponent`  one component belonging to this transform

## Returns
+ `energy`  positive physical energy in m3 s-2

## Discussion

Cross terms inside the selected state are retained. Energies of disjoint
coefficient selectors need not sum to the energy of their union.
