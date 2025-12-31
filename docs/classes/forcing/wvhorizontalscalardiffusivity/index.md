---
layout: default
title: WVHorizontalScalarDiffusivity
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 10
---

#  WVHorizontalScalarDiffusivity

Horizontal laplacian damping with viscosity and diffusivity


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVHorizontalScalarDiffusivity < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
The damping is a simple horizontal Laplacian, designed to mimic the
[HorizontalScalarDiffusivity in
Oceananigans](https://clima.github.io/OceananigansDocumentation/stable/appendix/library/#Oceananigans.TurbulenceClosures.HorizontalScalarDiffusivity)
to allow for direct comparison between the models. This should
probably be used in combination with WVVerticalScalarDiffusivity. In
general, you should be using the
[`WVAdaptiveDamping`](WVAdaptiveDamping).

The specific form of the forcing is given by 
 
$$
\begin{align}
\mathcal{S}_u &= \nu \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \night) u \\
\mathcal{S}_v &= \nu \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \night)  v \\
\mathcal{S}_w &= \nu \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \night)  w \\
\mathcal{S}_\eta &= \kappa \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \night)  \eta
\end{align}
$$
 
which is just your standard Laplacian viscosity, $$\nu$$, and diffusivity, $$\kappa$$, in
the horizontal. This should be combined with
`WVVerticalScalarDiffusivity` for a complete closure. For help
choosing appropriate values, see the notes in
[`WVAdaptiveDamping`](WVAdaptiveDamping).
 
### Usage
 
Assuming there is a WVTransform instance wvt, to add this forcing,
 
```matlab
wvt.addForcing(WVHorizontalScalarDiffusivity(wvt,nu=1e-4, kappa=1e-6));
```
 
 
### Notes
 
This is currently implemented in the spatial domain, an is
thus highly un-optimized.
 
     



## Topics
+ Initialization
  + [`WVHorizontalScalarDiffusivity`](/classes/forcing/wvhorizontalscalardiffusivity/wvhorizontalscalardiffusivity.html) initialize the WVHorizontalScalarDiffusivity
+ Properties
  + [`kappa`](/classes/forcing/wvhorizontalscalardiffusivity/kappa.html) horizontal diffusivity
  + [`nu`](/classes/forcing/wvhorizontalscalardiffusivity/nu.html) horizontal viscosity
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/wvhorizontalscalardiffusivity/classrequiredpropertynames.html) Returns the required property names for the class


---