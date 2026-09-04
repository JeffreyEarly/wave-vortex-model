---
layout: default
title: setDrifterPositions
parent: WVModel
grand_parent: Class documentation
nav_order: 50
mathjax: true
---

#  setDrifterPositions

Set positions of drifter-like particles to be advected.


---

## Declaration
```matlab
 setDrifterPositions(self,x,y,z,trackedFields,options)
```
## Parameters
+ `x`  x-coordinate locations of the particles
+ `y`  y-coordinate locations of the particles
+ `z`  optional z-coordinate locations of the particles
+ `trackedFields`  variable names to sample along each trajectory
+ `advectionInterpolation`  (optional) `linear` (default) or `spline` interpolation for particle advection
+ `trackedVarInterpolation`  (optional) `linear` (default) or `spline` interpolation for tracked fields

## Discussion
