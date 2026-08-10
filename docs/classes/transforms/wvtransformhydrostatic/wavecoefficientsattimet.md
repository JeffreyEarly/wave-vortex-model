---
layout: default
title: waveCoefficientsAtTimeT
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 287
mathjax: true
---

#  waveCoefficientsAtTimeT

Return positive- and negative-frequency coefficients at the current time.


---

## Declaration
```matlab
 [Apt,Amt] = waveCoefficientsAtTimeT()
```
## Returns
+ `Apt`  positive-frequency coefficients at `t`, with spectral shape
+ `Amt`  negative-frequency coefficients at `t`, with spectral shape

## Discussion
Return positive- and negative-frequency coefficients at the current time.

The method winds the stored coefficients from reference time `t0` to `t` using `Omega` and leaves `Ap` and `Am` unchanged.

```matlab
[Apt,Amt] = wvt.waveCoefficientsAtTimeT;
```
