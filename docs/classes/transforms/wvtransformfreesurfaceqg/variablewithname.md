---
layout: default
title: variableWithName
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 242
mathjax: true
---

#  variableWithName

Compute or retrieve one or more registered transform variables.


---

## Declaration
```matlab
 varargout = variableWithName(variableNames)
```
## Parameters
+ `variableNames`  names of registered state variables

## Returns
+ `varargout`  state-variable arrays in the requested order

## Discussion

Request several variables in one call to preserve their requested order:

```matlab
[u,v,eta] = wvt.variableWithName('u','v','eta');
```
