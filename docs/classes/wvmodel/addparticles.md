---
layout: default
title: addParticles
parent: WVModel
grand_parent: Classes
nav_order: 8
mathjax: true
---

#  addParticles

Add particles to be advected by the flow.


---

## Declaration
```matlab
 addParticles(name,isXYOnly,x,y,z,trackedFieldNames,options)
```
## Parameters
+ `name`  a unique name to call the particles
+ `isXYOnly`  whether particles are advected only in the horizontal dimensions
+ `x`  x-coordinate location of the particles
+ `y`  y-coordinate location of the particles
+ `z`  z-coordinate location of the particles
+ `trackedFieldNames`  strings of variable names
+ `advectionInterpolation`  (optional) `linear` (default) or `spline` interpolation for particle advection
+ `trackedVarInterpolation`  (optional) `linear` or `spline` (default) interpolation for tracked fields
+ `absToleranceXY`  (adapative) absolute tolerance in meters for particle advection in (x,y). 1e-1 (default)
+ `absToleranceZ`  (adapative) absolute tolerance  in meters for particle advection in (z). 1e-2 (default)

## Discussion

                        
