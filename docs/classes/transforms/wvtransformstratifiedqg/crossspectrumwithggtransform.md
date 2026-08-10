---
layout: default
title: crossSpectrumWithGgTransform
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 57
mathjax: true
---

#  crossSpectrumWithGgTransform

Compute a real modal cross-spectrum using the G-basis transform.


---

## Declaration
```matlab
 spectrum = crossSpectrumWithGgTransform(firstField,secondField)
```
## Parameters
+ `firstField`  first G-space field with shape `[Nx Ny Nz]`
+ `secondField`  second G-space field with shape `[Nx Ny Nz]`

## Returns
+ `spectrum`  real cross-spectrum with shape `[Nj Nkl]`

## Discussion
Compute a real modal cross-spectrum using the G-basis transform.

The result is the normalized real part of the product of the first transformed field and the complex conjugate of the second.
