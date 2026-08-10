---
layout: default
title: klGrid
parent: WVTransformBarotropicQG
grand_parent: Transforms
nav_order: 94
mathjax: true
---

#  klGrid

Return the barotropic spectral-coordinate arrays.


---

## Declaration
```matlab
 [K,L] = klGrid()
```
## Returns
+ `K`  x-direction angular wavenumbers in radians per meter
+ `L`  y-direction angular wavenumbers in radians per meter

## Discussion
Return the barotropic spectral-coordinate arrays.

`[K,L] = wvt.klGrid` returns angular wavenumbers in radians per meter with shape `[1 Nkl]`.

```matlab
[K,L] = wvt.klGrid;
```
