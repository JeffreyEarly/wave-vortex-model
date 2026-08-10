---
layout: default
title: isDensityInValidRange
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 163
mathjax: true
---

#  isDensityInValidRange

Test whether total density remains within the no-motion density range.


---

## Declaration
```matlab
 flag = isDensityInValidRange()
```
## Returns
+ `flag`  `true` when every total-density value lies within the no-motion range

## Discussion

A valid adiabatic rearrangement cannot contain density values
outside the range spanned by the no-motion profile.
