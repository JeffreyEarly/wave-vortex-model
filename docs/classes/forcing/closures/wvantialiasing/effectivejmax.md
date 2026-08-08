---
layout: default
title: effectiveJMax
parent: WVAntialiasing
grand_parent: Closures
nav_order: 6
mathjax: true
---

#  effectiveJMax

returns the effective highest vertical mode


---

## Declaration
```matlab
 flag = effectiveJMax(other)
```
## Returns
+ `effectiveJMax`  double

## Discussion

  The effective highest vertical modeis the highest fully resolved
  mode in the model. This value takes into account
  anti-aliasing, and is thus appropriate for setting damping
  operators.
