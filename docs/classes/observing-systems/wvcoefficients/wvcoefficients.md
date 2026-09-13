---
layout: default
title: WVCoefficients
parent: WVCoefficients
grand_parent: Observing systems
nav_order: 1
mathjax: true
---

#  WVCoefficients

Create a coefficient observer with local spectral tolerances.


---

## Declaration
```matlab
 self = WVCoefficients(model,options)
```
## Parameters
+ `model`  owning WVModel
+ `options`  energy scale, policy, and optional invariant scales

## Returns
+ `self`  coefficient observing system

## Discussion

Family scaling is available for v5 free-surface QG and Boussinesq.
Empty invariant scales match the energy floor at the first retained
mode and lowest nonzero wavenumber, separately for each endpoint.
Boundary scales use displacement anomalies, in m^(3/2); PV uses m/s.
