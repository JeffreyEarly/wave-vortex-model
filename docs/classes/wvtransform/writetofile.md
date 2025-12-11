---
layout: default
title: writeToFile
parent: WVTransform
grand_parent: Classes
nav_order: 112
mathjax: true
---

#  writeToFile

Write this instance to NetCDF file.


---

## Declaration
```matlab
 ncfile = writeToFile(path,properties,options)
```
## Parameters
+ `path`  path to write file
+ `properties`  strings of property names.
+ `shouldOverwriteExisting`  (optional) boolean indicating whether or not to overwrite an existing file at the path. Default 0. 
+ `shouldAddDefaultVariables`  (optional) boolean indicating whether or not add default variables `A0`,`Ap`,`Am`,`t`. Default 1.
+ `attributes`  (optional) dictionary containing additional attributes to add thet NetCDF file

## Discussion

  Writes the WVTransform instance to file, with enough information to
  re-initialize. Pass additional variables to the variable list that
  should also be written to file.
 
  Subclasses should add any necessary properties or variables to the
  variable list before calling this superclass method.
 
              
