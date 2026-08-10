---
layout: default
title: xyzGrid
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 294
mathjax: true
---

#  xyzGrid

Return the three-dimensional spatial coordinate arrays.


---

## Declaration
```matlab
 [X,Y,Z] = xyzGrid()
```
## Returns
+ `X`  x-coordinate array in meters with shape `[Nx Ny Nz]`
+ `Y`  y-coordinate array in meters with shape `[Nx Ny Nz]`
+ `Z`  vertical-coordinate array in meters with shape `[Nx Ny Nz]`

## Discussion
Return the three-dimensional spatial coordinate arrays.

`[X,Y,Z] = wvt.xyzGrid` returns arrays of shape `[Nx Ny Nz]` formed with `ndgrid(wvt.x,wvt.y,wvt.z)`.

```matlab
[X,Y,Z] = wvt.xyzGrid;
```
