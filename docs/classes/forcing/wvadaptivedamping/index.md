---
layout: default
title: WVAdaptiveDamping
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 2
---

#  WVAdaptiveDamping

Adaptive small-scale damping


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVAdaptiveDamping < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
  This damping operator is a linear closure designed not to mix
  geostrophic and wavemodes. This requires setting the diffusivity
  equal to the viscosity. It also uses the spectral vanishing viscosity
  filter to prevent any damping below a particular wavenumber.
 
 
    


## Topics
+ Other
  + [`WVAdaptiveDamping`](/classes/forcing/wvadaptivedamping/wvadaptivedamping.html) initialize the WVNonlinearFlux nonlinear flux
  + [`assumedEffectiveHorizontalGridResolution`](/classes/forcing/wvadaptivedamping/assumedeffectivehorizontalgridresolution.html) 
  + [`buildDampingOperator`](/classes/forcing/wvadaptivedamping/builddampingoperator.html) Builds the damping operator
  + [`classRequiredPropertyNames`](/classes/forcing/wvadaptivedamping/classrequiredpropertynames.html) Returns the required property names for the class
  + [`damp`](/classes/forcing/wvadaptivedamping/damp.html) 
  + [`dampingTimeScale`](/classes/forcing/wvadaptivedamping/dampingtimescale.html) Computes the damping time scale
  + [`forcingDidChangeNotification`](/classes/forcing/wvadaptivedamping/forcingdidchangenotification.html) 
  + [`forcingListener`](/classes/forcing/wvadaptivedamping/forcinglistener.html) 
  + [`j_damp`](/classes/forcing/wvadaptivedamping/j_damp.html) wavenumber at which the significant scale damping starts.
  + [`j_no_damp`](/classes/forcing/wvadaptivedamping/j_no_damp.html) wavenumber below which there is zero damping
  + [`k_damp`](/classes/forcing/wvadaptivedamping/k_damp.html) wavenumber at which the significant scale damping starts.
  + [`k_no_damp`](/classes/forcing/wvadaptivedamping/k_no_damp.html) wavenumber below which there is zero damping
  + [`spectralVanishingViscosityFilter`](/classes/forcing/wvadaptivedamping/spectralvanishingviscosityfilter.html) Builds the spectral vanishing viscosity operator


---