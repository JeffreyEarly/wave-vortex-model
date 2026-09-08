---
layout: default
title: coefficientStateForTransform
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 64
mathjax: true
---

#  coefficientStateForTransform

Express compatible resolved content in a target transform's coefficient convention.


---

## Declaration
```matlab
 [state,assessment] = coefficientStateForTransform(target,options)
```
## Parameters
+ `target`  same model class and physical problem at target resolution
+ `options.modeTolerance`  maximum relative per-mode physical shape residual
+ `options.quadratureCount`  comparison quadrature count; default twice the larger Nz plus one

## Returns
+ `state`  target-shaped family structure with absent target content zero
+ `assessment`  positive field error, discarded-field and per-family energies, retained mismatch and matched counts

## Discussion

Match Fourier integers, physical vertical mode labels and active endpoints.
A scalar normalization/phase alignment is permitted for each matching mode;
the resolved modes are never mixed or replaced. Incompatible mode shapes
raise an error. Both objects remain unchanged. The returned state represents
the source at source.t, using target.t0; set target.t accordingly on adoption.
Assessment uses a common refined positive physical quadrature and includes
balanced cross terms. Discarded-field energy is not source minus target energy.
