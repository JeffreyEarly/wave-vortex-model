---
layout: default
title: variableWithName
parent: WVTransform
grand_parent: Classes
nav_order: 121
mathjax: true
---

#  variableWithName

Compute or retrieve one or more registered transform variables.


---

## Declaration
```matlab
 [varargout] = variableWithName(self, variableNames)
```
## Parameters
+ `variableNames` registered variable names.

## Discussion

Outputs are returned in caller order. Requesting any uncached output evaluates its owning operation, including every output of a multiple-output operation, and stores the results in the transform cache. Unknown names produce a clear lookup error.
