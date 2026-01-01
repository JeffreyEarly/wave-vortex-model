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
 
This damping operator is a linear closure that dynamically changes
its amplitude to keep the Reynolds number at the grid scale equal to
one. This closure is ideal for a spin-up problem where the amplitude
of the flow is changing.

This closure has a number of noteworthy features:
 
- It does not mix geostrophic and wave modes, which requires setting
the diffusivity equal to the viscosity.
- The properties `k_no_damp` and `j_no_damp` indicate the wavenumber and
mode below which there is zero damping, due to the spectral vanishing
viscosity filter.
- The properties `k_damp` and `j_damp` are *estimates* of the
wavenumber and mode above which significant damping will occur.
 
The damping operator acts in the spectral domain, directly damping
the wave-vortex coefficients.
 
$$
\begin{align}
    \partial_t A_\pm^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_\pm^{k\ell j} - \nu_z \lambda_j^{-2} A_\pm^{k\ell j} \\
    \partial_t A_0^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_0^{k\ell j} - \nu_z \lambda_j^{-2} A_0^{k\ell j}
\end{align}
$$
 
where
 
$$
\nu_z = \nu \lambda^2_\textrm{min} k^2_\textrm{max} = \nu \lambda^2_\textrm{min} \left( \frac{\pi}{\Delta} \right)^2
$$
 
is chosen to make the damping isotropic. The notation here is that
$$\Delta$$ is the horizontal grid resolution and
$$\lambda^2_\textrm{min}$$ is the smallest resolved radius of
deformation. The value of $$\nu$$ is set as
 
$$
\nu = \frac{U \Delta}{\pi^2}
$$
 
where $$U$$ is the maximum fluid velocity.
 
### Usage
 
Assuming there is a WVTransform instance wvt, to add this forcing,
 
```matlab
wvt.addForcing(WVAdaptiveDamping(wvt));
```
 
### Notes
 
This currently damps the non-hydrostatic wavemodes the same as the
hydrostatic geostrophic modes. The non-hydrostatic modes would have a
smaller deformation radius, and thus would be damped more strongly.
So arguably they're under-damped in a non-hydrostatic simulation.
 
       



## Topics
+ Initialization
  + [`WVAdaptiveDamping`](/classes/forcing/wvadaptivedamping/wvadaptivedamping.html) initialize the WVAdaptiveDamping
+ Properties
  + [`assumedEffectiveHorizontalGridResolution`](/classes/forcing/wvadaptivedamping/assumedeffectivehorizontalgridresolution.html) effective resolution used in the damping calculation
  + [`damp`](/classes/forcing/wvadaptivedamping/damp.html) spectral matrix that multiplies Ap,Am,A0 to damp
  + [`dampingTimeScale`](/classes/forcing/wvadaptivedamping/dampingtimescale.html) Computes the minimum damping time scale
  + [`j_damp`](/classes/forcing/wvadaptivedamping/j_damp.html) wavenumber at which the significant scale damping starts.
  + [`j_no_damp`](/classes/forcing/wvadaptivedamping/j_no_damp.html) wavenumber below which there is zero damping
  + [`k_damp`](/classes/forcing/wvadaptivedamping/k_damp.html) wavenumber at which the significant scale damping starts.
  + [`k_no_damp`](/classes/forcing/wvadaptivedamping/k_no_damp.html) wavenumber below which there is zero damping
+ Internal
  + [`buildDampingOperator`](/classes/forcing/wvadaptivedamping/builddampingoperator.html) Builds the damping operator
  + [`spectralVanishingViscosityFilter`](/classes/forcing/wvadaptivedamping/spectralvanishingviscosityfilter.html) Builds the spectral vanishing viscosity operator
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/wvadaptivedamping/classrequiredpropertynames.html) Returns the required property names for the class


---