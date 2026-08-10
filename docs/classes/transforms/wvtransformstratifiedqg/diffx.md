---
layout: default
title: diffX
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 63
mathjax: true
---

#  diffX

Differentiate a gridded field in the periodic x direction.


---

## Declaration
```matlab
 derivative = diffX(field,options)
```
## Parameters
+ `field`  gridded field with the transform's spatial shape
+ `options.n`  derivative order; default `1`

## Returns
+ `derivative`  x derivative with the same shape as `field`

## Discussion
Differentiate a gridded field in the periodic x direction.

The derivative is evaluated spectrally. The input and output retain the same spatial layout, and derivative order `n` defaults to `1`.

```matlab
dudx = wvt.diffX(u);
```
