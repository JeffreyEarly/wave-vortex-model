---
layout: default
title: addOperation
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 47
mathjax: true
---

#  addOperation

Register one or more operations and their output variables.


---

## Discussion

The complete request is validated before annotations, lookup maps, or
cached values are changed. Existing operations are replaced only when
`shouldOverwriteExisting` is true. For an operation array, replacements
are evaluated in caller order and the last conflicting operation wins.
