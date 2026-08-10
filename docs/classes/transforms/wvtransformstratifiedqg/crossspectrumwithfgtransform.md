---
layout: default
title: crossSpectrumWithFgTransform
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 56
mathjax: true
---

#  crossSpectrumWithFgTransform

Compute a real modal cross-spectrum using the F-basis transform.


---

## Declaration
```matlab
 spectrum = crossSpectrumWithFgTransform(firstField,secondField)
```
## Parameters
+ `firstField`  first F-space field with shape `[Nx Ny Nz]`
+ `secondField`  second F-space field with shape `[Nx Ny Nz]`

## Returns
+ `spectrum`  real cross-spectrum with shape `[Nj Nkl]`

## Discussion
Compute a real modal cross-spectrum using the F-basis transform.

The result is the normalized real part of the product of the first transformed field and the complex conjugate of the second.
