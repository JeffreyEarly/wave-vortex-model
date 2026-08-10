---
layout: default
title: diffY
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 64
mathjax: true
---

#  diffY

Differentiate a gridded field in the periodic y direction.


---

## Declaration
```matlab
 derivative = diffY(field,options)
```
## Parameters
+ `field`  gridded field with the transform's spatial shape
+ `options.n`  derivative order; default `1`

## Returns
+ `derivative`  y derivative with the same shape as `field`

## Discussion
Differentiate a gridded field in the periodic y direction.

The derivative is evaluated spectrally. The input and output retain the same spatial layout, and derivative order `n` defaults to `1`.

```matlab
dudy = wvt.diffY(u);
```
