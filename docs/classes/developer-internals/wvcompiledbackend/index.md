---
layout: default
title: WVCompiledBackend
has_children: false
has_toc: false
mathjax: true
parent: Developer internals
grand_parent: Class documentation
nav_order: 2
---

#  WVCompiledBackend

Inspect and build the source-only compiled constant-stratification backend.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVCompiledBackend</code></pre></div></div>

## Overview

`WVCompiledBackend` is a developer-facing capability and build surface.
It does not select a computational backend for model objects. Detection
is side-effect free with respect to downloads and compilation; building
is always an explicit action.

```matlab
capabilities = WVCompiledBackend.capabilities();
capabilities = WVCompiledBackend.build();
```




## Topics


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Inspect compiled support
  + [`capabilities`](/classes/developer-internals/wvcompiledbackend/capabilities.html) Inspect native compiled-backend support without downloading or building.
+ Build compiled support
  + [`build`](/classes/developer-internals/wvcompiledbackend/build.html) Compile, validate, and transactionally install the pinned native provider.
+ Test compiled support
  + [`WVCompiledBackend`](/classes/developer-internals/wvcompiledbackend/wvcompiledbackend.html)


---