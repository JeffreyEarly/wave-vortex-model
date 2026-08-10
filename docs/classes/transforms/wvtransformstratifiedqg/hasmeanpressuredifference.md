---
layout: default
title: hasMeanPressureDifference
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 93
mathjax: true
---

#  hasMeanPressureDifference

Diagnose an MDA mean-pressure difference between the boundaries.


---

## Declaration
```matlab
 flag = hasMeanPressureDifference()
```
## Returns
+ `flag`  scalar logical indicating a resolved MDA boundary-pressure difference

## Discussion

Only the mean-density-anomaly (MDA) component can contribute
to a horizontally averaged pressure difference between the
top and bottom boundaries. The diagnostic evaluates

$$
\Delta \bar p_{\mathrm{mda}} =
\left|\langle p_{\mathrm{mda,top}}\rangle_{xy}
-\langle p_{\mathrm{mda,bottom}}\rangle_{xy}\right|
$$

relative to the maximum absolute MDA pressure. It returns
`true` when the relative difference is greater than `1e-5`.
Transforms without an MDA component return `false`. Other
flow components and common pressure-gauge offsets do not
enter the calculation.
