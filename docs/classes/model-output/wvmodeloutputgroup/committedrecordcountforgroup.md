---
layout: default
title: committedRecordCountForGroup
parent: WVModelOutputGroup
grand_parent: Model output
nav_order: 5
mathjax: true
---

#  committedRecordCountForGroup

Return the contiguous committed prefix of an output group.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 count = committedRecordCountForGroup(group)
```
## Discussion

Legacy groups without the finite-time protocol retain their raw
unlimited-dimension behavior.
