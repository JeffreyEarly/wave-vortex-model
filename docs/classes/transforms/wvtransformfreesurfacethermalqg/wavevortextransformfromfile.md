---
layout: default
title: waveVortexTransformFromFile
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 236
mathjax: true
---

#  waveVortexTransformFromFile

Restore a canonical thermal snapshot without a scientific mode solve.


---

## Parameters
+ `path`  snapshot NetCDF path
+ `options.iTime`  snapshot index, currently 1 only
+ `options.shouldReadOnly`  open the returned file read-only

## Returns
+ `w`  restored thermal transform
+ `file`  caller-owned open NetCDF file when requested
