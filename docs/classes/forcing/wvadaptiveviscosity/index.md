---
layout: default
title: WVAdaptiveViscosity
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 4
---

#  WVAdaptiveViscosity

Adaptive small-scale damping


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVAdaptiveViscosity < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
The damping is a simple Laplacian, but with a spectral vanishing viscosity (SVV) operator applied that prevents any damping below a cutoff wavenumber, adapted to the current fluid velocity. The SVV operator adjusts the wavenumbers being damped depending on whether anti-aliasing is applied.


## Topics
+ Other
  + [`F0_damp`](/classes/forcing/wvadaptiveviscosity/f0_damp.html) 
  + [`Fpm_damp`](/classes/forcing/wvadaptiveviscosity/fpm_damp.html) 
  + [`WVAdaptiveViscosity`](/classes/forcing/wvadaptiveviscosity/wvadaptiveviscosity.html) initialize the WVNonlinearFlux nonlinear flux
  + [`buildDampingOperator`](/classes/forcing/wvadaptiveviscosity/builddampingoperator.html) Builds the damping operator
  + [`classRequiredPropertyNames`](/classes/forcing/wvadaptiveviscosity/classrequiredpropertynames.html) Returns the required property names for the class
  + [`dampingTimeScale`](/classes/forcing/wvadaptiveviscosity/dampingtimescale.html) Computes the damping time scale
  + [`k_damp`](/classes/forcing/wvadaptiveviscosity/k_damp.html) wavenumber at which the significant scale damping starts.
  + [`k_no_damp`](/classes/forcing/wvadaptiveviscosity/k_no_damp.html) wavenumber below which there is zero damping
  + [`spectralVanishingViscosityFilter`](/classes/forcing/wvadaptiveviscosity/spectralvanishingviscosityfilter.html) Builds the spectral vanishing viscosity operator


---