---
layout: default
title: setWaveForcingCoefficients
parent: WVFixedAmplitudeForcing
grand_parent: Classes
nav_order: 11
mathjax: true
---

#  setWaveForcingCoefficients

set the amplitude to fix for the wave part of the flow


---

## Declaration
```matlab
  setWaveForcingCoefficients(Apbar,Ambar,options)
```
## Parameters
+ `Apbar`  Ap fixed amplitude
+ `Ambar`  Am fixed amplitude
+ `MAp`  (optional) forcing mask, Ap. 1s at the forced modes, 0s at the unforced modes. Default is MAp = abs(Apbar) > 1e-6*max(abs(Apbar(:)))
+ `MAm`  (optional) forcing mask, Am. 1s at the forced modes, 0s at the unforced modes. Default is MAm = abs(Ambar) > 1e-6*max(abs(Ambar(:)))

## Discussion

  This function will automatically remove modes set in the
  damping region of the WVAdapativeDamping forcing, if present.
 
            
