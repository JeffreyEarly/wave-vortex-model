---
layout: default
title: modelOutputGroupFromGroup
parent: WVModelOutputGroup
grand_parent: Classes
nav_order: 10
mathjax: true
---

#  modelOutputGroupFromGroup

initialize a WVModelOutputGroup instance from NetCDF file


---

## Declaration
```matlab
 outputGroup = modelOutputGroupFromGroup(group,model)
```
## Parameters
+ `group`  the NetCDFGroup to be used
+ `model`  the WVModel to be used

## Returns
+ `outputGroup`  a new instance of WVModelOutputGroup

## Discussion

  Subclasses to should override this method to enable model
  restarts. This method works in conjunction with -writeToFile
  to provide restart capability.
 
          
