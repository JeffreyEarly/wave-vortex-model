---
layout: default
title: initWithMeanDensityAnomaly
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 150
mathjax: true
---

#  initWithMeanDensityAnomaly

Initialize the fluid state with a mean-density anomaly.


---

## Declaration
```matlab
 initWithMeanDensityAnomaly(eta)
```
## Parameters
+ `eta`  function handle that takes a single argument, eta(Z)

## Discussion

Clear `Ap`, `Am`, and `A0`, then project the supplied
horizontally uniform isopycnal displacement onto the internal
mean-density-anomaly modes.

```matlab
eta = @(z) 10*sin(pi*(z+wvt.Lz)/wvt.Lz);
wvt.initWithMeanDensityAnomaly(eta);
```

It is important to note that because the WVTransform
de-aliases by default, you will not likely get exactly the
same function out that you put in. The high-modes are
removed.
