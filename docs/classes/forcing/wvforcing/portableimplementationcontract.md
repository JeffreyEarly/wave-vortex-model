---
layout: default
title: portableImplementationContract
parent: WVForcing
grand_parent: Forcing
nav_order: 15
mathjax: true
---

#  portableImplementationContract

Describe availability of the paired portable C++ implementation.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 contract = portableImplementationContract(self)
```
## Parameters
+ `self`  forcing to inspect

## Returns
+ `contract`  scalar portable implementation contract

## Discussion

The base class is intentionally unavailable. A supported
concrete forcing overrides this method with a versioned,
data-only contract. Portable execution still requires an exact
source-level C++ registration.
