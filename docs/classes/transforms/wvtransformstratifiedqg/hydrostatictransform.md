---
layout: default
title: hydrostaticTransform
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 97
mathjax: true
---

#  hydrostaticTransform

Create the corresponding hydrostatic wave-vortex transform.


---

## Declaration
```matlab
 wvt = hydrostaticTransform()
```
## Returns
+ `wvt`  corresponding `WVTransformHydrostatic` instance

## Discussion
Create the corresponding hydrostatic wave-vortex transform.

For a stratified QG transform, this method constructs a `WVTransformHydrostatic` with the same domain, stratification, planetary parameters, time, coefficients, and forcing configuration.

```matlab
wvtHydrostatic = wvtQG.hydrostaticTransform;
```
