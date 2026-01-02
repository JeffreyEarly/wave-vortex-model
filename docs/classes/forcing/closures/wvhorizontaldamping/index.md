---
layout: default
title: WVHorizontalDamping
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 4
---

#  WVHorizontalDamping

Horizontal laplacian damping with viscosity and diffusivity


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVHorizontalDamping < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
The damping is a simple horizontal Laplacian, designed to mimic the
[HorizontalScalarDiffusivity in
Oceananigans](https://clima.github.io/OceananigansDocumentation/stable/appendix/library/#Oceananigans.TurbulenceClosures.HorizontalScalarDiffusivity)
to allow for direct comparison between the models. This is intended to be used in combination with WVVerticalScalarDiffusivity. In
general, you should be using the
[`WVAdaptiveDamping`](../WVAdaptiveDamping).

The specific form of the forcing is given by 
 
$$
\begin{align}
\mathcal{S}_u &= \nu \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \right) u \\
\mathcal{S}_v &= \nu \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \right)  v \\
\mathcal{S}_w &= \nu \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \right)  w \\
\mathcal{S}_\eta &= \kappa \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \right)  \eta
\end{align}
$$
 
which is just your standard Laplacian viscosity, $$\nu$$, and diffusivity, $$\kappa$$, in
the horizontal. This should be combined with
[`WVVerticalDamping`](../WVVerticalDamping) for a complete closure. For help
choosing appropriate values, see the notes in
[`WVAdaptiveDamping`](../WVAdaptiveDamping).
 
### Usage
 
Assuming there is a WVTransform instance wvt, to add this forcing,
 
```matlab
wvt.addForcing(WVHorizontalDamping(wvt,nu=1e-4, kappa=1e-6));
```
 
 
### Notes
 
This is currently implemented in the spatial domain, an is
thus highly un-optimized.
 
     



## Topics
+ Initialization
  + [`WVHorizontalDamping`](/classes/forcing/closures/wvhorizontaldamping/wvhorizontaldamping.html) initialize the WVHorizontalDamping
+ Properties
  + [`kappa`](/classes/forcing/closures/wvhorizontaldamping/kappa.html) horizontal diffusivity
  + [`nu`](/classes/forcing/closures/wvhorizontaldamping/nu.html) horizontal viscosity
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvhorizontaldamping/classrequiredpropertynames.html) Returns the required property names for the class


---