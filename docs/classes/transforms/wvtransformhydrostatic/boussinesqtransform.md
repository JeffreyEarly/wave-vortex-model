---
layout: default
title: boussinesqTransform
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 75
mathjax: true
---

#  boussinesqTransform

Create the corresponding nonhydrostatic Boussinesq transform.


---

## Declaration
```matlab
 wvt = boussinesqTransform()
```
## Returns
+ `wvt`  corresponding `WVTransformBoussinesq` instance

## Discussion
Create the corresponding nonhydrostatic Boussinesq transform.

The new transform preserves the domain, stratification, planetary parameters, time, coefficients, forcing configuration, and no-motion-profile choice while changing the dynamical approximation.

```matlab
wvtBoussinesq = wvtHydrostatic.boussinesqTransform;
```
