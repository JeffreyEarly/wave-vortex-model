---
layout: default
title: implementation
parent: WVSpatialDerivativeDispatch
grand_parent: Developer internals
nav_order: 3
mathjax: true
---

#  implementation

Return the measured implementation for one exact configuration.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `backend`  active backend, `"builtin"` or `"fftw"`
+ `operation`  `"diffX"`, `"diffY"`, `"diffZF"`, `"diffZG"`, `"F-all"`, or `"G-all"`
+ `Nxyz`  exact spatial grid shape `[Nx Ny Nz]`
+ `derivativeOrder`  derivative order from 1 through 4
+ `isHydrostatic`  whether the constant-stratification model is hydrostatic

## Returns
+ `id`  selected implementation identifier

## Discussion
