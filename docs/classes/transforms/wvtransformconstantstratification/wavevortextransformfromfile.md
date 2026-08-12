---
layout: default
title: waveVortexTransformFromFile
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 303
mathjax: true
---

#  waveVortexTransformFromFile

Restore a WVTransformConstantStratification instance from an existing file


---

## Declaration
```matlab
 wvt = waveVortexTransformFromFile(path,options)
```
## Parameters
+ `path`  path to a NetCDF file
+ `iTime`  (optional) time index to initialize from (default 1)
+ `shouldReadOnly`  (optional) open the returned NetCDFFile read-only (default true)
+ `computationalBackend`  runtime backend override, `"matlab"` (default) or `"compiled"`

## Discussion

This static method is called by WVTransform.waveVortexTransformFromFile
and should not need to be called directly.

With one output, the temporary NetCDF file is closed before
returning. With two outputs, the caller owns the returned
NetCDFFile and must close it.
