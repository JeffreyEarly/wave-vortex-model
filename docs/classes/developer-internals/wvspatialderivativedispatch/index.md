---
layout: default
title: WVSpatialDerivativeDispatch
has_children: false
has_toc: false
mathjax: true
parent: Developer internals
grand_parent: Class documentation
nav_order: 5
---

#  WVSpatialDerivativeDispatch

Encode benchmarked spatial-derivative implementation choices.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef (Sealed) WVSpatialDerivativeDispatch</code></pre></div></div>

## Overview

Records are intentionally exact. Horizontal and all-derivative paths
are selected only for grid shapes measured by `derivative-dispatch-v1`;
no performance result is extrapolated to an untested shape, derivative
order, backend, or hydrostatic configuration.

```matlab
id = WVSpatialDerivativeDispatch.implementation( ...
    "fftw","diffX",[256 256 65],1,false);
```




## Topics


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Inspect spatial-derivative dispatch
  + [`WVSpatialDerivativeDispatch`](/classes/developer-internals/wvspatialderivativedispatch/wvspatialderivativedispatch.html)
  + [`allRecords`](/classes/developer-internals/wvspatialderivativedispatch/allrecords.html) Return the immutable derivative-dispatch records.
  + [`implementation`](/classes/developer-internals/wvspatialderivativedispatch/implementation.html) Return the measured implementation for one exact configuration.


---