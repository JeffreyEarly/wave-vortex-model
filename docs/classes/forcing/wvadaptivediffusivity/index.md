---
layout: default
title: WVAdaptiveDiffusivity
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 3
---

#  WVAdaptiveDiffusivity

Adaptive small-scale diffusivity


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVAdaptiveViscosity < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
  The damping is a simple Laplacian, but with a spectral vanishing
  viscosity (SVV) operator applied that prevents any damping below a
  cutoff wavenumber, adapted to the current fluid velocity. The SVV operator adjusts the wavenumbers being
  damped depending on whether anti-aliasing is applied.
 
 
    


## Topics
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/wvadaptivediffusivity/classrequiredpropertynames.html) Returns the required property names for the class
+ Properties
  + [`dampingTimeScale`](/classes/forcing/wvadaptivediffusivity/dampingtimescale.html) Computes the minimum damping time scale
+ Other
  + [`WVAdaptiveDiffusivity`](/classes/forcing/wvadaptivediffusivity/wvadaptivediffusivity.html) initialize the WVNonlinearFlux nonlinear flux
  + [`buildDampingOperator`](/classes/forcing/wvadaptivediffusivity/builddampingoperator.html) Builds the damping operator
  + [`damp`](/classes/forcing/wvadaptivediffusivity/damp.html) 
  + [`spectralVanishingViscosityFilter`](/classes/forcing/wvadaptivediffusivity/spectralvanishingviscosityfilter.html) Builds the spectral vanishing viscosity operator


---