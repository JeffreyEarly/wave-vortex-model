---
layout: default
title: WVSpectralVanishingViscosity
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 13
---

#  WVSpectralVanishingViscosity

Small-scale damping


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVNonlinearFlux < <a href="/classes/wvnonlinearfluxoperation/" title="WVForcingFluxOperation">WVForcingFluxOperation</a></code></pre></div></div>

## Overview
 
The damping is a simple Laplacian, but with a spectral vanishing
viscosity (SVV) operator applied that prevents any damping below a
cutoff wavenumber. The SVV operator adjusts the wavenumbers being
damped depending on whether anti-aliasing is applied.
 
 
  


## Topics
+ Other
  + [`WVSpectralVanishingViscosity`](/classes/forcing/wvspectralvanishingviscosity/wvspectralvanishingviscosity.html) initialize the WVNonlinearFlux nonlinear flux
  + [`buildDampingOperator`](/classes/forcing/wvspectralvanishingviscosity/builddampingoperator.html) 
  + [`classRequiredPropertyNames`](/classes/forcing/wvspectralvanishingviscosity/classrequiredpropertynames.html) 
  + [`damp`](/classes/forcing/wvspectralvanishingviscosity/damp.html) 
  + [`dampingTimeScale`](/classes/forcing/wvspectralvanishingviscosity/dampingtimescale.html) 
  + [`k_damp`](/classes/forcing/wvspectralvanishingviscosity/k_damp.html) wavenumber at which the significant scale damping starts.
  + [`k_no_damp`](/classes/forcing/wvspectralvanishingviscosity/k_no_damp.html) wavenumber below which there is zero damping
  + [`nu_xy`](/classes/forcing/wvspectralvanishingviscosity/nu_xy.html) 
  + [`nu_z`](/classes/forcing/wvspectralvanishingviscosity/nu_z.html) 
  + [`spectralVanishingViscosityFilter`](/classes/forcing/wvspectralvanishingviscosity/spectralvanishingviscosityfilter.html) 
  + [`uv_damp`](/classes/forcing/wvspectralvanishingviscosity/uv_damp.html) 


---