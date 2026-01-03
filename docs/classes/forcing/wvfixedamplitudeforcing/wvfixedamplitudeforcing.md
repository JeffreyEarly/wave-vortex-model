---
layout: default
title: WVFixedAmplitudeForcing
parent: WVFixedAmplitudeForcing
grand_parent: Classes
nav_order: 7
mathjax: true
---

#  WVFixedAmplitudeForcing

initialize the WVFixedAmplitudeForcing


---

## Declaration
```matlab
 self = WVFixedAmplitudeForcing(wvt,options)
```
## Parameters
+ `wvt`  a WVTransform instance
+ `name`  (required) name of this forcing
+ `Apbar`  (optional) amplitude of Ap matrix to fix
+ `Ambar`  (optional) amplitude of Am matrix to fix
+ `A0bar`  (optional) amplitude of A0 matrix to fix
+ `Ap_indices`  (optional) index of coefficient in Ap matrix to fix
+ `Am_indices`  (optional) index of coefficient in Am matrix to fix
+ `A0_indices`  (optional) index of coefficient in A0 matrix to fix

## Returns
+ `self`  a WVFixedAmplitudeForcing instance

## Discussion

  You must pass the instance of the WVTransform to be used and
  you must also specify a unique name for the forcing.
 
                    
