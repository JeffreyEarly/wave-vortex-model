---
layout: default
title: portableImplementationContract
parent: WVObservingSystem
grand_parent: Observing systems
nav_order: 12
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
+ `self`  observing system to inspect

## Returns
+ `contract`  scalar portable implementation contract

## Discussion

The base class is intentionally unavailable. A supported
concrete observing system overrides this method with a
versioned, data-only contract. The portable runtime still
requires an exact source-level C++ registration.
