---
layout: default
title: klModeNumberFromIndex
parent: WVTransformBoussinesq
grand_parent: Classes
nav_order: 151
mathjax: true
---

#  klModeNumberFromIndex

return mode number from a linear index into a WV matrix


---

## Declaration
```matlab
 [kMode,lMode] = klModeNumberFromIndex(self,linearIndex)
```
## Parameters
+ `linearIndex`  a non-negative integer number

## Returns
+ `kMode`  integer
+ `lMode`  integer

## Discussion

  This function will return the mode numbers (kMode,lMode)
  given some linear index into a WV structured matrix.
 
          
