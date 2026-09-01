---
layout: default
title: WVPseudoTopographicWaveGeneration
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 9
---

#  WVPseudoTopographicWaveGeneration

Generate internal waves from prescribed barotropic flow over topography.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVPseudoTopographicWaveGeneration < WVForcing</code></pre></div></div>

## Overview

`WVPseudoTopographicWaveGeneration` prescribes a horizontally uniform
barotropic velocity

$$
\mathbf{U}_{\mathrm{bt}}(t)
=R(\tau)\operatorname{Re}\left\{
\widehat{\mathbf{U}}_{\mathrm{bt}}e^{-i\omega\tau}\right\},
\qquad \tau=t-t_s,
$$

where $$t_s$$ is `startTime`, $$\omega$$ is `frequency`, and $$R$$ is
either unity or a half-cosine startup ramp. For upward-positive
topographic height $$h(x,y)$$, the linearized bottom kinematic
boundary condition is

$$
g_b(x,y,t)=w(z_b)=\mathbf{U}_{\mathrm{bt}}(t)\cdot\nabla_H h,
$$

with Fourier representation

$$
\widehat{g}_b=U_{\mathrm{bt},x}(ik\widehat h)
+U_{\mathrm{bt},y}(i\ell\widehat h).
$$

Let $$\pi_\pm(z_b)$$ denote the kinematic bottom pressure of a unit
current-time wave coefficient and let $$E_\pm$$ denote its
`Apm_TE_factor`. The projected current-time tendencies are

$$
\dot A_{\pm,t}
=\frac{\pi_\pm^*(z_b)\widehat g_b}{E_\pm}.
$$

The implementation precomputes the pressure-gradient response and
converts these tendencies to the stored reference-time coefficients
with `conjPhase` for `Ap` and `phase` for `Am`. This normalization
makes modal energy input equal the bottom pressure work.

Generation is limited to the valid `Ap` and `Am` wave masks, the
requested horizontal-wavenumber and vertical-mode bounds, and, by
default, the exact zero-damping support of active
`WVAdaptiveDamping` objects. The incoming `A0` tendency is unchanged.
Select a standard constituent with `darwinSymbol`, or supply a custom
angular `frequency`.

```matlab
forcing = WVPseudoTopographicWaveGeneration(wvt,topographicHeight=h,barotropicVelocityAmplitude=[0.05; 0],darwinSymbol="M2");
wvt.removeAllForcing();
wvt.addForcing(forcing);
```




## Topics
+ Create the forcing
  + [`WVPseudoTopographicWaveGeneration`](/classes/forcing/wvpseudotopographicwavegeneration/wvpseudotopographicwavegeneration.html) Create a prescribed bottom wave-generation forcing.
+ Inspect forcing configuration
  + [`topographicHeight`](/classes/forcing/wvpseudotopographicwavegeneration/topographicheight.html) Upward-positive topographic height $$h(x,y)$$ in meters.
  + [`barotropicVelocityAmplitude`](/classes/forcing/wvpseudotopographicwavegeneration/barotropicvelocityamplitude.html) Complex barotropic velocity amplitude in meters per second.
  + [`frequency`](/classes/forcing/wvpseudotopographicwavegeneration/frequency.html) Barotropic angular frequency $$\omega$$ in radians per second.
  + [`darwinSymbol`](/classes/forcing/wvpseudotopographicwavegeneration/darwinsymbol.html) Darwin symbol used to select the tidal frequency.
  + [`rampDuration`](/classes/forcing/wvpseudotopographicwavegeneration/rampduration.html) Duration of the half-cosine startup ramp in seconds.
  + [`startTime`](/classes/forcing/wvpseudotopographicwavegeneration/starttime.html) Time at which the prescribed barotropic forcing begins, in seconds.
  + [`shouldAvoidAdaptiveDamping`](/classes/forcing/wvpseudotopographicwavegeneration/shouldavoidadaptivedamping.html) Whether generation avoids active adaptive damping.
  + [`maximumForcedHorizontalWavenumber`](/classes/forcing/wvpseudotopographicwavegeneration/maximumforcedhorizontalwavenumber.html) Largest radial horizontal wavenumber forced, in radians per meter.
  + [`maximumForcedVerticalMode`](/classes/forcing/wvpseudotopographicwavegeneration/maximumforcedverticalmode.html) Largest vertical wave-mode index forced.
+ Evaluate prescribed forcing
  + [`barotropicVelocityAtTime`](/classes/forcing/wvpseudotopographicwavegeneration/barotropicvelocityattime.html) Evaluate the prescribed horizontally uniform current.
  + [`bottomVelocityAtTime`](/classes/forcing/wvpseudotopographicwavegeneration/bottomvelocityattime.html) Evaluate the bottom kinematic velocity.
  + [`spectralGenerationMask`](/classes/forcing/wvpseudotopographicwavegeneration/spectralgenerationmask.html) Return the spectral region eligible for bottom-wave generation.
+ Generate forcing inputs
  + [`goffAbyssalHillTopography`](/classes/forcing/wvpseudotopographicwavegeneration/goffabyssalhilltopography.html) Generate periodic Goff abyssal-hill topography.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/wvpseudotopographicwavegeneration/classrequiredpropertynames.html) Return the forcing properties required for restart.
+ Forcing internals
  + [`barotropicVelocityComponent`](/classes/forcing/wvpseudotopographicwavegeneration/barotropicvelocitycomponent.html) Coordinate for the barotropic-velocity components.


---