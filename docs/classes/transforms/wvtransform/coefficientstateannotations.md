---
layout: default
title: coefficientStateAnnotations
parent: WVTransform
grand_parent: Transforms
nav_order: 23
mathjax: true
---

#  coefficientStateAnnotations

Return canonical coefficient-family annotations in integrator order.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 annotations = coefficientStateAnnotations(self)
```
## Returns
+ `annotations`  ordered WVCoefficientAnnotation array

## Discussion

Legacy transforms expose the applicable `Ap`, `Am`, and `A0` families.
New transforms override this method when their coefficient vocabulary or
logical dimensions differ.
