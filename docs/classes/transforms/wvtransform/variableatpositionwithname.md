---
layout: default
title: variableAtPositionWithName
parent: WVTransform
grand_parent: Classes
nav_order: 117
mathjax: true
---

#  variableAtPositionWithName

Primary method for accessing the dynamical variables on the at any


---

## Declaration
```matlab
 [varargout] = variableAtPositionWithName(self,x,y,z,variableNames,options)
```
## Parameters
+ `x`  array of x-positions
+ `y`  array of y-positions
+ `z`  array of z-positions
+ `variableNames`  strings of variable names.
+ `interpolationMethod`  (optional) `linear`,`spline`,`exact`. Default `linear`.

## Discussion
position in the domain.
 
  Computes (or retrieves from cache) any known state variables and computes
  their values at the requested positions (x,y,z)
 
  The method argument specifies how off-grid values should be interpolated.
  Use 'exact' for the slow, but accurate, spectral interpolation. Otherwise
  use 'spline' or some other method used by Matlab's interp function.
 
              
