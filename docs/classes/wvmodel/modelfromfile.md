---
layout: default
title: modelFromFile
parent: WVModel
grand_parent: Classes
nav_order: 34
mathjax: true
---

#  modelFromFile

Initialize a model from an existing file


---

## Declaration
```matlab
 model = modelFromFile(path)
```
## Parameters
+ `path`  path to a NetCDF file

## Discussion

  A WVModel will be initialized from the specified path. The model will
  have this file designated as its only output file. All groups in that
  file are restored, but other files previously written by the same model
  are not reconstructed. The file must contain one complete coefficient
  stream. Linear versus nonlinear dynamics is restored when the model
  metadata is present; older files retain the nonlinear default.

  Runtime integrator objects are not persisted. Configure the desired
  fixed or adaptive integrator before continuing the restored model.
 
      
