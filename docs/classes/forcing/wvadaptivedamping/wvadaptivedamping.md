---
layout: default
title: WVAdaptiveDamping
parent: WVAdaptiveDamping
grand_parent: Classes
nav_order: 1
mathjax: true
---

#  WVAdaptiveDamping

initialize the WVNonlinearFlux nonlinear flux


---

## Declaration
```matlab
 nlFlux = WVAdaptiveViscosity(wvt)
```
## Parameters
+ `wvt`  a WVTransform instance

## Returns
+ `self`  a WVAdaptiveViscosity instance

## Discussion

  Note that you should never need to set
  shouldAssumeAntialiasing to true, because the WVGeometry will
  hand back the correct effective grid resolution whether you
  enabled it at the transform level, or as a filter.
 
      
