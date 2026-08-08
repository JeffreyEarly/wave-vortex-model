---
layout: default
title: solutionForModeAtIndex
parent: WVTotalFlowComponent
grand_parent: Flow components
nav_order: 10
mathjax: true
---

#  solutionForModeAtIndex

Return analytical solutions from the complete primary-flow basis.


---

## Declaration
```matlab
 solutions = solutionForModeAtIndex(index,options)
```
## Parameters
+ `index`  positive integer scalar or column vector with values no greater than nModes
+ `amplitude`  (optional) 'wvt' or 'random' (default)

## Returns
+ `solutions`  scalar or column vector of WVOrthogonalSolution objects

## Discussion

  Total-flow indices run from 1 through `nModes`. Primary flow
  components are ordered lexically by `shortName`, and each
  component contributes one contiguous range while retaining its
  own local mode ordering. Scalar inputs return a scalar solution;
  column-vector inputs return solutions in the requested order.

  Set `amplitude='wvt'` to reconstruct each solution from the
  corresponding coefficient currently stored by the transform.
  Set `amplitude='random'` to generate an appropriate random
  amplitude for each requested solution.
