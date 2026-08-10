---
layout: default
title: waveVortexTransformWithExplicitAntialiasing
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 305
mathjax: true
---

#  waveVortexTransformWithExplicitAntialiasing

Create an explicit-antialiasing transform with the same grid.


---

## Declaration
```matlab
 wvtExplicit = waveVortexTransformWithExplicitAntialiasing()
```
## Returns
+ `wvtExplicit`  transform using an explicit antialias filter

## Discussion
Create an explicit-antialiasing transform with the same grid.

This method converts an implicitly dealiased transform into a full-grid transform with `WVAntialiasing` attached. It preserves time, coefficients, and compatible forcing.

```matlab
wvtExplicit = wvt.waveVortexTransformWithExplicitAntialiasing;
```
