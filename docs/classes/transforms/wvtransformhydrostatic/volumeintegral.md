---
layout: default
title: volumeIntegral
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 281
mathjax: true
---

#  volumeIntegral

Compute the horizontally averaged depth integral of a scalar field.


---

## Declaration
```matlab
 integralValue = volumeIntegral(field)
```
## Parameters
+ `field`  scalar field with shape `[Nx Ny Nz]`

## Returns
+ `integralValue`  horizontal-mean depth integral, with the field units multiplied by meters

## Discussion
Compute the horizontally averaged depth integral of a scalar field.

`volumeIntegral` is a function handle that horizontally averages a field and integrates the result with the vertical quadrature weights `z_int`. Its input has shape `[Nx Ny Nz]`. Despite the historical property name, it does not multiply by the horizontal domain area.

```matlab
depth = wvt.volumeIntegral(ones(wvt.spatialMatrixSize));
```
