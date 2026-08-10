---
layout: default
title: WVAntialiasing
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 6
---

#  WVAntialiasing

Apply explicit spectral antialias filtering for diagnostics.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVAntialiasing < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

This closure removes coefficient tendencies in aliased modes and sets
those coefficients to zero after every integration step. The
horizontal mask uses the transform's quadratic-aliasing rule. Vertical
modes with `j >= Nj` are discarded; `Nj` defaults to
`floor(2*wvt.Nj/3)`.

Transform-level antialiasing is enabled by default and is more
efficient because discarded modes are never computed. Explicit
antialiasing is intended for measuring the filter's effect on energy
and potential enstrophy. Construct the transform with
`shouldAntialias=false` before adding this closure. It is compatible
with wave-bearing and QG transforms.

### Example

```matlab
wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,5],N0=5.2e-3,latitude=45,isHydrostatic=true,shouldAntialias=false);
wvt.addForcing(WVAntialiasing(wvt));
```




## Topics
+ Create the forcing
  + [`WVAntialiasing`](/classes/forcing/closures/wvantialiasing/wvantialiasing.html) Create explicit antialias filtering for a transform.
+ Inspect forcing configuration
  + [`Nj`](/classes/forcing/closures/wvantialiasing/nj.html) Number of retained vertical modes.
+ Inspect forcing or damping scales
  + [`effectiveHorizontalGridResolution`](/classes/forcing/closures/wvantialiasing/effectivehorizontalgridresolution.html) Return the shortest fully retained horizontal wavelength.
  + [`effectiveJMax`](/classes/forcing/closures/wvantialiasing/effectivejmax.html) Return the highest retained vertical-mode number.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvantialiasing/classrequiredpropertynames.html) Returns the required property names for the class
+ Forcing internals
  + [`M`](/classes/forcing/closures/wvantialiasing/m.html) Logical-shape spectral mask of discarded coefficients.


---