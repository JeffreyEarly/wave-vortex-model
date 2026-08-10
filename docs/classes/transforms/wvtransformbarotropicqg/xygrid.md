---
layout: default
title: xyGrid
parent: WVTransformBarotropicQG
grand_parent: Transforms
nav_order: 184
mathjax: true
---

#  xyGrid

Return the two-dimensional spatial coordinate arrays.


---

## Declaration
```matlab
 [X,Y] = xyGrid()
```
## Returns
+ `X`  x-coordinate array in meters with shape `[Nx Ny]`
+ `Y`  y-coordinate array in meters with shape `[Nx Ny]`

## Discussion
Return the two-dimensional spatial coordinate arrays.

For a barotropic transform, `[X,Y] = wvt.xyGrid` returns arrays of shape `[Nx Ny]` formed with `ndgrid(wvt.x,wvt.y)`.

```matlab
[X,Y] = wvt.xyGrid;
```
