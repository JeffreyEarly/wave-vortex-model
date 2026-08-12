---
layout: default
title: spectralVariableWithResolution
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 250
mathjax: true
---

#  spectralVariableWithResolution

create a new variable with different resolution


---

## Declaration
```matlab
 varX2 = spectralVariableWithResolution(wvtX2,var)
```
## Parameters
+ `var`  a variable with dimensions [Nj Nkl]
+ `wvtX2`  a WVTransform of different size.

## Returns
+ `varX2`  matrix the size Nklj

## Discussion

Given a variable with dimensions `[Nj Nkl]`, this returns a new variable
with dimensions matching `wvtX2`. Coefficients are matched by their
integer `(kMode,lMode,jMode)` identities. Modes absent from the target are
discarded and target modes absent from the source are initialized to zero.
