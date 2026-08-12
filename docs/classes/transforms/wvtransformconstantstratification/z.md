---
layout: default
title: z
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 311
mathjax: true
---

#  z

Three-dimensional vertical-coordinate array in meters.


---

## Discussion
Three-dimensional vertical-coordinate array in meters.

`Z` has spatial shape `[Nx Ny Nz]` and is formed with `ndgrid(x,y,z)`. It varies along the third dimension.

```matlab
[X,Y,Z] = wvt.xyzGrid;
```
