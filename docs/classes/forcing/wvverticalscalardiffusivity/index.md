---
layout: default
title: WVVerticalScalarDiffusivity
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 16
---

#  WVVerticalScalarDiffusivity

Vertical viscosity and diffusivity


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVVerticalScalarDiffusivity < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
  The damping is designed to mimic the VerticalScalarDiffusivity in
  Oceananigans to allow for direct comparison between the models. This
  should probably be used in combination with
  `WVHorizontalScalarDiffusivity`. In general, you should be using the
  [`WVAdaptiveDamping`](WVAdaptiveDamping).
  
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
  WVHorizontalScalarDiffusivity for a complete closure. For help
  choosing appropriate values, see the notes in
  [`WVAdaptiveDamping`](WVAdaptiveDamping).
 
  ### Usage
 
  Assuming there is a WVTransform instance wvt, to add this forcing,
 
  ```matlab
  wvt.addForcing(WVVerticalScalarDiffusivity(wvt,nu=5e-4, kappa=1e-6));
  ```
 
 
  ### Notes
 
  This is currently implemented in the spatial domain, an is
  thus highly un-optimized.
 
       
  


## Topics
+ Properties
  + [`dLnN2`](/classes/forcing/wvverticalscalardiffusivity/dlnn2.html) variable stratification factor
  + [`kappa`](/classes/forcing/wvverticalscalardiffusivity/kappa.html) vertical diffusivity
  + [`nu`](/classes/forcing/wvverticalscalardiffusivity/nu.html) vertical viscosity
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/wvverticalscalardiffusivity/classrequiredpropertynames.html) Returns the required property names for the class
+ Other
  + [`WVVerticalScalarDiffusivity`](/classes/forcing/wvverticalscalardiffusivity/wvverticalscalardiffusivity.html) initialize the WVVerticalScalarDiffusivity


---