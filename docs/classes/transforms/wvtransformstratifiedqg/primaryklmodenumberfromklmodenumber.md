---
layout: default
title: primaryKLModeNumberFromKLModeNumber
parent: WVTransformStratifiedQG
grand_parent: Classes
nav_order: 123
mathjax: true
---

#  primaryKLModeNumberFromKLModeNumber

takes any valid WV mode number and returns the primary mode number


---

## Declaration
```matlab
 [kMode,lMode] = primaryKLModeNumberFromKLModeNumber(kMode,lMode)
```
## Parameters
+ `kMode`  integer
+ `lMode`  integer

## Returns
+ `kMode`  integer
+ `lMode`  integer

## Discussion

  The function first confirms that the mode numbers are valid,
  and then converts any conjugate mode numbers to primary mode
  numbers.
 
  The result is affected by the chosen conjugateDimension.
 
            
