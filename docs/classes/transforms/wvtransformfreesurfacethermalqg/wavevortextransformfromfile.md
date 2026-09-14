---
layout: default
title: waveVortexTransformFromFile
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 250
mathjax: true
---

#  waveVortexTransformFromFile

Restore thermal scientific state, a committed coefficient record and forcing.


---

## Parameters
+ `path`  snapshot or model-output NetCDF path
+ `options.iTime`  committed record index; Inf selects the last
+ `options.shouldReadOnly`  open the returned file read-only

## Returns
+ `w`  restored thermal transform
+ `file`  caller-owned open NetCDF file when requested

## Discussion
Stored generators rebuild numerical caches on integrator attachment; no
scientific mode construction or qualification is performed by restoration.
