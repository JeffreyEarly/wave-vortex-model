---
layout: default
title: setMeanDensityAnomaly
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 230
mathjax: true
---

#  setMeanDensityAnomaly

Set the mean-density-anomaly component.


---

## Declaration
```matlab
 setMeanDensityAnomaly(eta)
```
## Parameters
+ `eta`  function handle that takes a single argument, eta(Z)

## Discussion

Overwrite existing mean-density-anomaly coefficients with the
projection of `eta` while preserving other flow components.
Other components of the flow will remain unaffected.

```matlab
eta = @(z) 10*sin(pi*(z+wvt.Lz)/wvt.Lz);
wvt.setMeanDensityAnomaly(eta);
```

It is important to note that because the WVTransform
de-aliases by default, you will not likely get exactly the
same function out that you put in. The high-modes are
removed.
