---
layout: default
title: isValidPrimaryKLModeNumber
parent: WVTransformConstantStratification
grand_parent: Classes
nav_order: 129
mathjax: true
---

#  isValidPrimaryKLModeNumber

return a boolean indicating whether (k,l) is a valid primary (non-conjugate) WV mode number


---

## Declaration
```matlab
 bool = isValidPrimaryKLModeNumber(kMode,lMode)
```
## Parameters
+ `kMode`  integer
+ `lMode`  integer

## Returns
+ `bool`  [0 1]

## Discussion

  returns a boolean indicating whether (k,l) is a valid
  *primary* WV mode number. Even if a mode number is available
  in the DFT matrix, it does not mean it is a valid WV mode
  number, e.g., it may be removed due to aliasing.
 
  The result is affected by the chosen conjugateDimension.
 
          
