---
layout: default
title: totalEnergyOfFlowComponent
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 224
mathjax: true
---

#  totalEnergyOfFlowComponent

Compute the energy carried by one flow component.


---

## Declaration
```matlab
 energy = totalEnergyOfFlowComponent(flowComponent)
```
## Parameters
+ `flowComponent`  component belonging to this transform

## Returns
+ `energy`  horizontally averaged, depth-integrated physical energy

## Discussion
Compute the energy carried by one flow component.

The calculation applies the component's `maskAp`, `maskAm`, and `maskA0` to the transform coefficients and sums the corresponding energy factors.

```matlab
waveEnergy = wvt.totalEnergyOfFlowComponent(wvt.waveComponent);
geostrophicEnergy = wvt.totalEnergyOfFlowComponent(wvt.geostrophicComponent);
```
