---
layout: default
title: WVAntialiasing
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 7
---

#  WVAntialiasing

Antialiasing filter


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVAntialiasing < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
This forcing removes (sets to zero) energy in the largest 1/3 modes
to prevent quadratic aliasing. This is the correct de-aliasing for
the horizontal fourier modes, but is not exactly correct for the
vertical modes in variable stratification. You can thus manually set
`Nj`, otherwise it will default to `options.Nj = floor(2*wvt.Nj/3);`.
 
**Very important** You should almost never use this forcing, as
de-aliasing is built-in at the transform level and enabled by
default. For performance reasons is far more optimal to simply never
compute the de-aliased modes. The purpose of this forcing to allow
direct measurement of the effect of the de-aliasing on energy and
potential enstrophy. It is quite slow and thus we recommend it be
used for diagnostic purposes only.
 
### Usage
 
This is likely to change in the future, but at the moment several of
the transforms have a function that will make a new transform in the
identical state, but with the antialiasing filter explicitly added.
 
```matlab
wvtAA = wvt.waveVortexTransformWithExplicitAntialiasing();
```
 
     
  


## Topics
+ Properties
  + [`M`](/classes/forcing/closures/wvantialiasing/m.html) spectral matrix that multiplies Ap,Am,A0 to zero out the aliased modes
  + [`effectiveHorizontalGridResolution`](/classes/forcing/closures/wvantialiasing/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
  + [`effectiveJMax`](/classes/forcing/closures/wvantialiasing/effectivejmax.html) returns the effective highest vertical mode
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvantialiasing/classrequiredpropertynames.html) Returns the required property names for the class
+ Other
  + [`WVAntialiasing`](/classes/forcing/closures/wvantialiasing/wvantialiasing.html) initialize the WVAntialiasing


---