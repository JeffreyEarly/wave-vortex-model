---
layout: default
title: WVAdaptiveDamping
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 1
---

#  WVAdaptiveDamping

Adaptive small-scale damping


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVAdaptiveDamping < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

 damping operator is a linear closure that dynamically changes
amplitude to keep the Reynolds number at the grid scale equal to
 This closure is ideal for a spin-up problem where the amplitude
he flow is changing.

 closure has a number of noteworthy features:

 does not mix geostrophic and wave modes, which requires setting
diffusivity equal to the viscosity.
e properties `k_no_damp` and `j_no_damp` indicate the wavenumber and
 below which there is zero damping, due to the spectral vanishing
osity filter.
e properties `k_damp` and `j_damp` are *estimates* of the
number and mode above which significant damping will occur.

damping operator acts in the spectral domain, directly damping
wave-vortex coefficients.

$$
in{align}
\partial_t A_\pm^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_\pm^{k\ell j} - \nu_z \lambda_j^{-2} A_\pm^{k\ell j} \\
\partial_t A_0^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_0^{k\ell j} - \nu_z \lambda_j^{-2} A_0^{k\ell j}
{align}
$$

e

$$
z = \nu \lambda^2_\textrm{min} k^2_\textrm{max} = \nu \lambda^2_\textrm{min} \left( \frac{\pi}{\Delta} \right)^2
$$

hosen to make the damping isotropic. The notation here is that
elta$$ is the horizontal grid resolution and
ambda^2_\textrm{min}$$ is the smallest resolved radius of
rmation. The value of $$\nu$$ is set as

$$
= \frac{U \Delta}{\pi^2}
$$

e $$U$$ is the maximum fluid velocity.

Usage

ming there is a WVTransform instance wvt, to add this forcing,

atlab
addForcing(WVAdaptiveDamping(wvt));
```

Notes

 currently damps the non-hydrostatic wavemodes the same as the
ostatic geostrophic modes. The non-hydrostatic modes would have a
ler deformation radius, and thus would be damped more strongly.
rguably they're under-damped in a non-hydrostatic simulation.





## Topics
+ Initialization
  + [`WVAdaptiveDamping`](/classes/forcing/closures/wvadaptivedamping/wvadaptivedamping.html) initialize the WVAdaptiveDamping
+ Properties
  + [`assumedEffectiveHorizontalGridResolution`](/classes/forcing/closures/wvadaptivedamping/assumedeffectivehorizontalgridresolution.html) effective resolution used in the damping calculation
  + [`damp`](/classes/forcing/closures/wvadaptivedamping/damp.html) spectral matrix that multiplies Ap,Am,A0 to damp
  + [`dampingTimeScale`](/classes/forcing/closures/wvadaptivedamping/dampingtimescale.html) Computes the minimum damping time scale
  + [`j_damp`](/classes/forcing/closures/wvadaptivedamping/j_damp.html) wavenumber at which the significant scale damping starts.
  + [`j_no_damp`](/classes/forcing/closures/wvadaptivedamping/j_no_damp.html) wavenumber below which there is zero damping
  + [`k_damp`](/classes/forcing/closures/wvadaptivedamping/k_damp.html) wavenumber at which the significant scale damping starts.
  + [`k_no_damp`](/classes/forcing/closures/wvadaptivedamping/k_no_damp.html) wavenumber below which there is zero damping
+ Internal
  + [`buildDampingOperator`](/classes/forcing/closures/wvadaptivedamping/builddampingoperator.html) Builds the damping operator
  + [`spectralVanishingViscosityFilter`](/classes/forcing/closures/wvadaptivedamping/spectralvanishingviscosityfilter.html) Builds the spectral vanishing viscosity operator
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvadaptivedamping/classrequiredpropertynames.html) Returns the required property names for the class


---