---
layout: default
title: addMeanDensityAnomaly
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 62
mathjax: true
---

#  addMeanDensityAnomaly

Add a mean-density anomaly to the existing fluid state.


---

## Declaration
```matlab
 addMeanDensityAnomaly(eta)
```
## Parameters
+ `eta`  function handle that takes a single argument, eta(Z)

## Discussion

The supplied horizontally uniform isopycnal displacement is
projected onto the internal mean-density-anomaly modes and
added to their `A0` coefficients.

```matlab
eta = @(z) 10*sin(pi*(z+wvt.Lz)/wvt.Lz);
wvt.addMeanDensityAnomaly(eta);
```

It is important to note that because the WVTransform
de-aliases by default, you will not likely get exactly the
same function out that you put in. The high-modes are
removed.
