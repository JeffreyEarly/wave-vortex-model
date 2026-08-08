---
layout: default
title: WVVerticalDamping
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 4
---

#  WVVerticalDamping

Vertical viscosity and diffusivity


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVVerticalDamping < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

The damping is designed to mimic the VerticalScalarDiffusivity in
Oceananigans to allow for direct comparison between the models. This
is intended be used in combination with
WVHorizontalDamping. In general, you should be using the
[`WVAdaptiveDamping`](/classes/forcing/closures/wvadaptivedamping/).

The specific form of the forcing is given by

$$
\begin{align}
\mathcal{S}_u &= \nu \frac{\partial^2 u}{\partial z^2} \\
\mathcal{S}_v &= \nu \frac{\partial^2 v }{\partial z^2} \\
\mathcal{S}_w &= \nu \frac{\partial^2 w}{\partial z^2} \\
\mathcal{S}_\eta &= \kappa \frac{\partial^2 \eta}{\partial z^2} - \kappa \frac{\partial}{\partial z} \ln N^2
\end{align}
$$

with viscosity, $$\nu$$, and diffusivity, $$\kappa$$. This should be combined with
[`WVHorizontalDamping`](/classes/forcing/closures/wvhorizontaldamping/) for a complete closure. For help
choosing appropriate values, see the notes in
[`WVAdaptiveDamping`](/classes/forcing/closures/wvadaptivedamping/).

### Usage

Assuming there is a WVTransform instance wvt, to add this forcing,

```matlab
wvt.addForcing(WVVerticalDamping(wvt,nu=5e-4, kappa=1e-6));
```

### Notes

This is currently implemented in the spatial domain and is
thus highly un-optimized.

For constant stratification, $$\partial_z \ln N^2=0$$ and the
stratification-gradient correction vanishes. The configured viscosity
and diffusivity are preserved when the forcing is copied to a
transform with a different resolution.





## Topics
+ Create forcing and closures
  + [`WVVerticalDamping`](/classes/forcing/closures/wvverticaldamping/wvverticaldamping.html) initialize the WVVerticalDamping


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvverticaldamping/classrequiredpropertynames.html) Returns the required property names for the class
+ Forcing internals
  + [`dLnN2`](/classes/forcing/closures/wvverticaldamping/dlnn2.html) variable stratification factor
  + [`kappa`](/classes/forcing/closures/wvverticaldamping/kappa.html) vertical diffusivity
  + [`nu`](/classes/forcing/closures/wvverticaldamping/nu.html) vertical viscosity


---