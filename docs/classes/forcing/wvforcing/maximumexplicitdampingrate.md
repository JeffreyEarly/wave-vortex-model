---
layout: default
title: maximumExplicitDampingRate
parent: WVForcing
grand_parent: Forcing
nav_order: 15
mathjax: true
---

#  maximumExplicitDampingRate

Return the forcing's explicit stability bound in inverse seconds.

> Developer documentation: this item describes internal implementation details.


---

## Discussion

The exponential controller calls this at every actual trial state.
The second argument supplies the evaluated physical uvMax; other
state-dependent bounds may inspect the owning transform. Ordinary
sources have no damping bound and return zero.
