---
layout: default
title: setGeostrophicForcingCoefficients
parent: WVFixedAmplitudeForcing
grand_parent: Classes
nav_order: 9
mathjax: true
---

#  setGeostrophicForcingCoefficients

set amplitude to fix for the geostrophic part of the flow


---

## Declaration
```matlab
 setGeostrophicForcingCoefficients(A0bar,options)
```
## Parameters
+ `A0bar`  A0 fixed amplitude
+ `MA0`  (optional) forcing mask, A0. 1s at the forced modes, 0s at the unforced modes. Default is MA0 = abs(A0bar) > 1e-6*max(abs(A0bar(:)))

## Discussion

  This function will automatically remove modes set in the
  damping region of the WVAdapativeDamping forcing, if present.
 
        
