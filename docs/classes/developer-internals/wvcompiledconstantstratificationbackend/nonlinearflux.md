---
layout: default
title: nonlinearFlux
parent: WVCompiledConstantStratificationBackend
grand_parent: Developer internals
nav_order: 5
mathjax: true
---

#  nonlinearFlux

Evaluate ordinary nonlinear advection in the compiled kernel.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [Fp,Fm,F0] = nonlinearFlux(Ap,Am,A0,t,t0)
```
## Parameters
+ `Ap`  positive-frequency `[Nj,Nkl]` coefficients
+ `Am`  negative-frequency `[Nj,Nkl]` coefficients
+ `A0`  zero-frequency `[Nj,Nkl]` coefficients
+ `t`  evaluation time in seconds
+ `t0`  coefficient reference time in seconds

## Returns
+ `Fp`  positive-frequency `[Nj,Nkl]` flux
+ `Fm`  negative-frequency `[Nj,Nkl]` flux
+ `F0`  zero-frequency `[Nj,Nkl]` flux

## Discussion
