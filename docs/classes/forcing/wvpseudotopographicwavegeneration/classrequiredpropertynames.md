---
layout: default
title: classRequiredPropertyNames
parent: WVPseudoTopographicWaveGeneration
grand_parent: Forcing
nav_order: 6
mathjax: true
---

#  classRequiredPropertyNames

Return the forcing properties required for restart.


---

## Declaration
```matlab
 requiredPropertyNames = classRequiredPropertyNames()
```
## Returns
+ `requiredPropertyNames`  property names required to reconstruct the forcing

## Discussion

  Derived gradients and modal responses are intentionally not
  persisted; construction against the restored transform
  rebuilds them.
