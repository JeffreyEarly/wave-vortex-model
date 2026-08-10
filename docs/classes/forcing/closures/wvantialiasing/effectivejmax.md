---
layout: default
title: effectiveJMax
parent: WVAntialiasing
grand_parent: Closures
nav_order: 6
mathjax: true
---

#  effectiveJMax

Return the highest retained vertical-mode number.


---

## Declaration
```matlab
 j_max = effectiveJMax()
```
## Returns
+ `j_max`  highest retained vertical-mode number

## Discussion

This dimensionless value accounts for the explicit vertical
mask and is appropriate when constructing damping operators.
