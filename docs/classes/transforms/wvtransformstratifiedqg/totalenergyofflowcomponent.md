---
layout: default
title: totalEnergyOfFlowComponent
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 200
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
+ `flowComponent`  component whose coefficient masks select the energy

## Returns
+ `energy`  horizontally averaged, depth-integrated energy per unit reference density

## Discussion
Compute the energy carried by one flow component.

The calculation applies the component's `maskAp`, `maskAm`, and `maskA0` to the transform coefficients and sums the corresponding energy factors.

```matlab
waveEnergy = wvt.totalEnergyOfFlowComponent(wvt.waveComponent);
geostrophicEnergy = wvt.totalEnergyOfFlowComponent(wvt.geostrophicComponent);
```
