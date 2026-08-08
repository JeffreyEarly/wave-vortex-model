---
layout: default
title: spectralVariableWithResolution
parent: WVTransform
grand_parent: Classes
nav_order: 95
mathjax: true
---

#  spectralVariableWithResolution

Create a spectral variable at a different resolution


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
  with dimensions matching `wvtX2`. Coefficients are matched by integer
  `(kMode,lMode,jMode)` identity. Modes absent from the target are discarded,
  and target modes absent from the source are initialized to zero.
 
          
