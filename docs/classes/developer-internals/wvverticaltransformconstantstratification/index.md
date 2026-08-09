---
layout: default
title: WVVerticalTransformConstantStratification
has_children: false
has_toc: false
mathjax: true
parent: Developer internals
grand_parent: Class documentation
nav_order: 4
---

#  WVVerticalTransformConstantStratification

Select and cache constant-stratification vertical transforms.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef (Sealed) WVVerticalTransformConstantStratification < handle</code></pre></div></div>

## Overview

This developer-facing strategy applies normalized DCT-I and DST-I
transforms to canonical vertical arrays shaped `[Nz,Nbatch]`. It is
independent of horizontal Fourier storage. With the builtin backend it
always evaluates the supplied dense matrix expression. With an active
FFTW backend it uses only the exact issue #43 eligibility records and
falls back to the same matrix expression everywhere else.

Cosine transforms retain the first `Nj` coefficients and discard all
excluded modes, including the Nyquist coefficient. Sine transforms add
the WaveVortex logical `j=0` zero row around FFTW's `Nz-2` interior-mode
representation. Scaling by `F_g`, `G_g`, `F_wg`, or `G_wg` remains the
responsibility of the geometry.

```matlab
strategy = WVVerticalTransformConstantStratification.create(Nz,Nj,"fftw");
coefficients = strategy.transformForward(values,"cosine",DCT);
values = strategy.transformBack(coefficients,"cosine",iDCT);
records = strategy.dispatchRecords();
```




## Topics


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Create a vertical-transform strategy
  + [`Nj`](/classes/developer-internals/wvverticaltransformconstantstratification/nj.html) Number of retained WaveVortex vertical modes.
  + [`Nz`](/classes/developer-internals/wvverticaltransformconstantstratification/nz.html) Number of physical vertical grid points.
  + [`backendIdentifier`](/classes/developer-internals/wvverticaltransformconstantstratification/backendidentifier.html) Active model-wide transform backend, `"builtin"` or `"fftw"`.
  + [`create`](/classes/developer-internals/wvverticaltransformconstantstratification/create.html) a vertical strategy for the active model backend.
+ Manage vertical-transform lifecycle
  + [`delete`](/classes/developer-internals/wvverticaltransformconstantstratification/delete.html) every cached FFTW plan idempotently.
+ Inspect vertical dispatch
  + [`dispatchRecords`](/classes/developer-internals/wvverticaltransformconstantstratification/dispatchrecords.html) Return stable, JSON-safe records for encountered operations.
+ Apply vertical transforms
  + [`transformBack`](/classes/developer-internals/wvverticaltransformconstantstratification/transformback.html) Transform `[Nj,Nbatch]` coefficients to `[Nz,Nbatch]` values.
  + [`transformForward`](/classes/developer-internals/wvverticaltransformconstantstratification/transformforward.html) Transform `[Nz,Nbatch]` values to `[Nj,Nbatch]` coefficients.


---