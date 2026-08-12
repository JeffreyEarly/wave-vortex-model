---
layout: default
title: capabilities
parent: WVCompiledBackend
grand_parent: Developer internals
nav_order: 3
mathjax: true
---

#  capabilities

Inspect native compiled-backend support without downloading or building.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 capabilities = WVCompiledBackend.capabilities()
```
## Returns
+ `capabilities`  schema `1.0.0` support, identity, validation, storage, build-attempt, and failure information

## Discussion

Expected unavailability is returned as structured data. This method does
not download source, invoke a compiler, create cache output, warn, or throw
because the provider is absent or unsupported.
