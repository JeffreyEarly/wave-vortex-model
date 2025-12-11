---
layout: default
title: WVTransformBarotropicQG
parent: WVTransformBarotropicQG
grand_parent: Classes
nav_order: 24
mathjax: true
---

#  WVTransformBarotropicQG

create geometry for 2D barotropic flow


---

## Declaration
```matlab
 wvt = Cartesian2DBarotropic(Lxyz, Nxyz, options)
```
## Parameters
+ `Lxy`  length of the domain (in meters) in the two coordinate directions, e.g. [Lx Ly]
+ `Nxy`  number of grid points in the two coordinate directions, e.g. [Nx Ny]
+ `shouldAntialias`  (optional) whether or not to de-alias for quadratic multiplications

## Returns
+ `wvt`  a new Cartesian2DBarotropic instance

## Discussion

  ```matlab
  Lxy = 50e3;
  Nxy = 256;
  wvt = Cartesian2DBarotropic([Lxy, Lxy], [Nxy, Nxy]);
  ```
 
            
