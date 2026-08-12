---
layout: default
title: WVCompiledConstantStratificationBackend
has_children: false
has_toc: false
mathjax: true
parent: Developer internals
grand_parent: Class documentation
nav_order: 3
---

#  WVCompiledConstantStratificationBackend

Own one compiled constant-stratification nonlinear-flux kernel.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef (Sealed) WVCompiledConstantStratificationBackend < handle</code></pre></div></div>

## Overview

This developer-facing adapter is the MATLAB ownership boundary for
the source-only compiled preview. It validates an already-built native
provider, creates exactly one MEX kernel, and returns MATLAB-owned
`[Nj,Nkl]` flux arrays. It never downloads, builds, or falls back.

Construct this object through `create`. Callers must delete it or its
owning transform to release all FFT plans and the MEX module lock.

- Developer: true



## Topics


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Compiled preview internals
  + [`capabilities`](/classes/developer-internals/wvcompiledconstantstratificationbackend/capabilities.html) Capability record validated during construction.
  + [`create`](/classes/developer-internals/wvcompiledconstantstratificationbackend/create.html) a compiled adapter for one constant-stratification transform.
  + [`delete`](/classes/developer-internals/wvcompiledconstantstratificationbackend/delete.html)
  + [`metadata`](/classes/developer-internals/wvcompiledconstantstratificationbackend/metadata.html) Return JSON-safe identity, storage, and runtime metadata.
  + [`nonlinearFlux`](/classes/developer-internals/wvcompiledconstantstratificationbackend/nonlinearflux.html) Evaluate ordinary nonlinear advection in the compiled kernel.


---