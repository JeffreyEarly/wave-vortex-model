---
layout: default
title: solutionForModeAtIndex
parent: WVPrimaryFlowComponent
grand_parent: Flow components
nav_order: 10
mathjax: true
---

#  solutionForModeAtIndex

return the analytical solution for the mode at this index


---

## Declaration
```matlab
 solution = solutionForModeAtIndex(index)
```
## Parameters
+ `index`  non-negative integer less than nModes
+ `amplitude`  (optional) 'wvt' or 'random' (default)

## Returns
+ `solution`  an instance of WVOrthogonalSolution

## Discussion

Returns WVOrthogonalSolution object for this index.
The solution indices run from 1:nModes.

The solution amplitude can be set to either 'wvt' or
'random'. Setting the amplitude='wvt' will use the amplitude
currently set in the wvt to initialize this solution.
Otherwise an appropriate random amplitude will be created.
