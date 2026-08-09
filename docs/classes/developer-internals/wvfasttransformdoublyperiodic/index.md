---
layout: default
title: WVFastTransformDoublyPeriodic
has_children: false
has_toc: false
mathjax: true
parent: Developer internals
grand_parent: Class documentation
nav_order: 2
---

#  WVFastTransformDoublyPeriodic

Define and select a doubly periodic horizontal-transform backend.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVFastTransformDoublyPeriodic</code></pre></div></div>

## Overview

Concrete adapters implement the horizontal Fourier transform and
derivative operations used by doubly periodic WaveVortex geometries.
The static `create` method keeps optional FFTW package discovery,
capability validation, local compilation, and fallback behavior out of
the geometry classes. The canonical WV grid is complete before `create`
is called; the selected adapter owns its Fourier storage layout.

`"builtin"` never queries FFTWTransforms. An explicit `"fftw"` request
accepts only the validated MATLAB-bundled half-x r2c/c2r contract from
FFTWTransforms 1.0.2 or later. If required, one local build is attempted
before capabilities are queried again. An unavailable request emits one
warning and returns the builtin adapter.

```matlab
[adapter,selection] = WVFastTransformDoublyPeriodic.create( ...
    geometry,Nz,"fftw");
```

This class is developer infrastructure rather than an end-user modeling
or extension API.




## Topics


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Select a horizontal-transform backend
  + [`WVFastTransformDoublyPeriodic`](/classes/developer-internals/wvfasttransformdoublyperiodic/wvfasttransformdoublyperiodic.html)
  + [`backendIdentifier`](/classes/developer-internals/wvfasttransformdoublyperiodic/backendidentifier.html) Stable identifier for the active horizontal-transform backend.
  + [`create`](/classes/developer-internals/wvfasttransformdoublyperiodic/create.html) Construct the requested backend or a safe builtin fallback.
  + [`diffX`](/classes/developer-internals/wvfasttransformdoublyperiodic/diffx.html)
  + [`diffY`](/classes/developer-internals/wvfasttransformdoublyperiodic/diffy.html)
  + [`fourierStorageLayout`](/classes/developer-internals/wvfasttransformdoublyperiodic/fourierstoragelayout.html)
  + [`transformFromSpatialDomainWithFourier`](/classes/developer-internals/wvfasttransformdoublyperiodic/transformfromspatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourier`](/classes/developer-internals/wvfasttransformdoublyperiodic/transformtospatialdomainwithfourier.html)


---