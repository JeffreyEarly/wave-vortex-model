---
layout: default
title: forcingFromGroup
parent: WVForcing
grand_parent: Classes
nav_order: 9
mathjax: true
---

#  forcingFromGroup

initialize a WVForcing instance from NetCDF file


---

## Declaration
```matlab
 force = forcingFromFile(group,wvt)
```
## Parameters
+ `wvt`  the WVTransform to be used

## Returns
+ `force`  a new instance of WVForcing

## Discussion

  Subclasses to should override this method to enable model
  restarts. This method works in conjunction with -writeToFile
  to provide restart capability.
 
        
