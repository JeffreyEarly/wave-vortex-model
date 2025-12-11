---
layout: default
title: WVAntialiasing
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 5
---

#  WVAntialiasing

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
+ Properties
  + [`effectiveHorizontalGridResolution`](/classes/forcing/wvantialiasing/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
+ Other
  + [`M`](/classes/forcing/wvantialiasing/m.html) 
  + [`WVAntialiasing`](/classes/forcing/wvantialiasing/wvantialiasing.html) initialize the WVNonlinearFlux nonlinear flux
  + [`classRequiredPropertyNames`](/classes/forcing/wvantialiasing/classrequiredpropertynames.html) 
  + [`effectiveJMax`](/classes/forcing/wvantialiasing/effectivejmax.html) 


---