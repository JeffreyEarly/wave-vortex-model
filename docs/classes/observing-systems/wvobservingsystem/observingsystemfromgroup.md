---
layout: default
title: observingSystemFromGroup
parent: WVObservingSystem
grand_parent: Classes
nav_order: 11
mathjax: true
---

#  observingSystemFromGroup

initialize a WVObservingSystem instance from NetCDF file


---

## Declaration
```matlab
 os = observingSystemFromGroup(group,wvt)
```
## Parameters
+ `model`  the WVModel to be used

## Returns
+ `os`  a new instance of WVObservingSystem

## Discussion

  Subclasses to should override this method to enable model
  restarts. This method works in conjunction with -writeToFile
  to provide restart capability.
 
        
