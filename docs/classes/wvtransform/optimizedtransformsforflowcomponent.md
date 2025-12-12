---
layout: default
title: optimizedTransformsForFlowComponent
parent: WVTransform
grand_parent: Classes
nav_order: 60
mathjax: true
---

#  optimizedTransformsForFlowComponent

returns optimized transforms that avoid unnecessary computation


---

## Discussion

  The mask structure has fields {Ap,Am,A0}, which have values of 0, 1, or a
  full array that is the spectral matrix size. The value will be set to 0
  if *either* the primary components OR this component have no active
  components. The value will be set to 1 if the primary component is
  nonzero, and this component has the same values. Otherwise, an array will
  be returned.
 
  The isMasked boolean is true if this flow component deviates from the
  total primary flow components in some fashion.
