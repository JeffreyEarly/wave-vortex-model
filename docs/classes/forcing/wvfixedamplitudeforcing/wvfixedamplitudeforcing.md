---
layout: default
title: WVFixedAmplitudeForcing
parent: WVFixedAmplitudeForcing
grand_parent: Classes
nav_order: 7
mathjax: true
---

#  WVFixedAmplitudeForcing

initialize the WVNonlinearFlux nonlinear flux


---

## Declaration
```matlab
 nlFlux = WVNonlinearFlux(wvt,options)
```
## Parameters
+ `wvt`  a WVTransform instance
+ `uv_damp`  (optional) characteristic speed used to set the damping. Try using wvt.uvMax.
+ `w_damp`  (optional) characteristic speed used to set the damping. Try using wvt.wMax.
+ `nu_xy`  (optional) coefficient for damping
+ `nu_z`  (optional) coefficient for damping

## Returns
+ `nlFlux`  a WVNonlinearFlux instance

## Discussion

              
