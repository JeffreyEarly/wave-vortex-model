---
layout: default
title: create
parent: WVCompiledConstantStratificationBackend
grand_parent: Developer internals
nav_order: 2
mathjax: true
---

#  create

a compiled adapter for one constant-stratification transform.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 backend = WVCompiledConstantStratificationBackend.create(wvt)
```
## Parameters
+ `wvt`  constant-stratification transform defining the immutable kernel configuration

## Returns
+ `backend`  validated compiled-kernel owner

## Discussion

The native provider must already have been built explicitly by
calling `WVCompiledBackend.build()`.
