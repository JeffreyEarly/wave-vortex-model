---
layout: default
title: removeOperation
parent: WVTransform
grand_parent: Classes
nav_order: 85
mathjax: true
---

#  removeOperation

Remove the exact registered operation and its cached outputs.


---

## Discussion

The supplied object must be the same handle that is registered with the transform. Removing a multiple-output operation removes all of its annotations, lookup entries, and cached outputs without clearing unrelated cached variables.
