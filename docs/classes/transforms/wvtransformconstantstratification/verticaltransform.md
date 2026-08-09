---
layout: default
title: verticalTransform
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 243
mathjax: true
---

#  verticalTransform

Layout-neutral vertical DCT-I/DST-I dispatch and plan cache.

> Developer documentation: this item describes internal implementation details.


---

## Discussion

The strategy operates on canonical `[Nz,Nbatch]` arrays and is
independent of horizontal Fourier storage. Call `dispatchRecords`
on this object to inspect which operations used FFTW.
