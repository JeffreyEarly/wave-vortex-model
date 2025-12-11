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
  have this file designated as its outputFile. Integrating the model will
  thus write to this file.
 
      
