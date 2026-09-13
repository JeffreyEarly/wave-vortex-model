---
layout: default
title: scopedEvaluation
parent: WVTransform
grand_parent: Transforms
nav_order: 89
mathjax: true
---

#  scopedEvaluation

Reuse compiled dependencies while the MATLAB state is unchanged.

> Developer documentation: this item describes internal implementation details.


---

## Discussion

Retain the returned onCleanup object until all consumers finish.
Nested scopes share their enclosing evaluation.
