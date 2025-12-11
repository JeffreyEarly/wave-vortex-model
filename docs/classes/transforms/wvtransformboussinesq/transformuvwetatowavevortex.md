---
layout: default
title: transformUVWEtaToWaveVortex
parent: WVTransformBoussinesq
grand_parent: Classes
nav_order: 228
mathjax: true
---

#  transformUVWEtaToWaveVortex

transform momentum variables $$(u,v,w,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.


---

## Declaration
```matlab
 [Ap,Am,A0] = transformUVWEtaToWaveVortex(U,V,N)
```
## Parameters
+ `u`  x-component of the momentum
+ `v`  y-component of the momentum
+ `w`  y-component of the momentum
+ `n`  scaled density anomaly
+ `t`  (optional) time of observations

## Returns
+ `Ap`  positive wave coefficients at reference time t0
+ `Am`  negative wave coefficients at reference time t0
+ `A0`  geostrophic coefficients at reference time t0

## Discussion

  This function tuned for constant stratification.
 
                    
