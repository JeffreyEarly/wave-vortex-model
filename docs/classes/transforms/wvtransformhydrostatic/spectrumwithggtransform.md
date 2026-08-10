---
layout: default
title: spectrumWithGgTransform
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 237
mathjax: true
---

#  spectrumWithGgTransform

Compute a modal autospectrum using the G-basis transform.


---

## Declaration
```matlab
 spectrum = spectrumWithGgTransform(field)
```
## Parameters
+ `field`  G-space field with shape `[Nx Ny Nz]`

## Returns
+ `spectrum`  nonnegative autospectrum with shape `[Nj Nkl]`

## Discussion
Compute a modal autospectrum using the G-basis transform.

The method transforms a gridded G-space field and applies the horizontal Hermitian and vertical normalization factors.

```matlab
spectrum = wvt.spectrumWithGgTransform(eta);
```
