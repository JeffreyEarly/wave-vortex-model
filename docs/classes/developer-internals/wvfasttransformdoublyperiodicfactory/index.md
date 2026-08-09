---
layout: default
title: WVFastTransformDoublyPeriodicFactory
has_children: false
has_toc: false
mathjax: true
parent: Developer internals
grand_parent: Class documentation
nav_order: 3
---

#  WVFastTransformDoublyPeriodicFactory

Select and construct a doubly periodic horizontal-transform backend.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVFastTransformDoublyPeriodicFactory</code></pre></div></div>

## Overview

This developer-facing factory keeps optional FFTW package discovery,
capability validation, local compilation, and fallback behavior out of
the geometry classes. The canonical WV grid is complete before the
factory is called; the selected adapter owns its Fourier storage layout.

`"builtin"` never queries FFTWTransforms. An explicit `"fftw"` request
accepts only the validated MATLAB-bundled half-x r2c/c2r contract from
FFTWTransforms 1.0.2 or later. If required, one local build is attempted
before the capabilities are queried again. An unavailable request emits
one warning and returns the builtin adapter.

```matlab
factory = WVFastTransformDoublyPeriodicFactory();
[adapter,selection] = factory.create(geometry,Nz,"fftw");
```

Protected service methods are narrow test seams. This class is developer
infrastructure rather than an end-user modeling or extension API.




## Topics


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Select a horizontal-transform backend
  + [`WVFastTransformDoublyPeriodicFactory`](/classes/developer-internals/wvfasttransformdoublyperiodicfactory/wvfasttransformdoublyperiodicfactory.html)
  + [`create`](/classes/developer-internals/wvfasttransformdoublyperiodicfactory/create.html) Construct the requested backend or a safe builtin fallback.


---