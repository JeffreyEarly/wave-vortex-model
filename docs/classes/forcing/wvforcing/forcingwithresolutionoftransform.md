---
layout: default
title: forcingWithResolutionOfTransform
parent: WVForcing
grand_parent: Forcing
nav_order: 10
mathjax: true
---

#  forcingWithResolutionOfTransform

Rebuild a forcing for a compatible transform resolution.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 force = forcingWithResolutionOfTransform(wvtX2)
```
## Parameters
+ `wvtX2`  compatible transform at the target resolution

## Returns
+ `force`  equivalent forcing owned by `wvtX2`

## Discussion

Subclasses that support transform resolution conversion override
this method and preserve their user configuration.
