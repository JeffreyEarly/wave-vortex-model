---
layout: default
title: WVFastTransformDoublyPeriodicFFTW
has_children: false
has_toc: false
mathjax: true
parent: Developer internals
grand_parent: Class documentation
nav_order: 3
---

#  WVFastTransformDoublyPeriodicFFTW

Apply memory-lean horizontal transforms through FFTWTransforms.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVFastTransformDoublyPeriodicFFTW < WVFastTransformDoublyPeriodic</code></pre></div></div>

## Overview

This developer-facing adapter stores horizontal Fourier coefficients
in Hermitian half-x form while preserving the canonical WaveVortex
grid shape `[Nz,Nkl]`. It owns one two-dimensional FFTW plan and no
real- or spectrum-sized persistent MATLAB array.

Forward transforms return normalized WaveVortex coefficients. Inverse
transforms assemble a uniquely owned transient half spectrum and use
FFTW's destructive c2r operation without additional normalization.
Spatial derivatives deliberately retain MATLAB's one-dimensional FFT
implementation until issue #74 evaluates derivative dispatch.

```matlab
adapter = WVFastTransformDoublyPeriodicFFTW(geometry,Nz);
coefficients = adapter.transformFromSpatialDomainWithFourier(u);
u = adapter.transformToSpatialDomainWithFourier(coefficients);
```




## Topics


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Create an FFTW adapter
  + [`Nz`](/classes/developer-internals/wvfasttransformdoublyperiodicfftw/nz.html) Number of independent horizontal-transform batches.
  + [`WVFastTransformDoublyPeriodicFFTW`](/classes/developer-internals/wvfasttransformdoublyperiodicfftw/wvfasttransformdoublyperiodicfftw.html) Create a half-x FFTW horizontal-transform adapter.
  + [`wvg`](/classes/developer-internals/wvfasttransformdoublyperiodicfftw/wvg.html) Geometry defining the horizontal WaveVortex grid.


---