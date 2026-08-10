---
layout: default
title: WVPseudoTopographicWaveGeneration
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 7
---

#  WVPseudoTopographicWaveGeneration

Generate internal waves from prescribed barotropic flow over topography.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVPseudoTopographicWaveGeneration < WVForcing</code></pre></div></div>

## Overview

`WVPseudoTopographicWaveGeneration` projects the first-order bottom
velocity

$$
g_b=\boldsymbol U_{\mathrm{bt}}(t)\boldsymbol{\cdot}\nabla_Hh
$$

onto the rigid-lid wave modes using their bottom pressure. The
projection is precomputed, so ordinary forcing calls add spectral
wave tendencies without a pressure solve or spatial transform. By
default, generation is projected outside the exact support of an
active `WVAdaptiveDamping`. Optional horizontal-wavenumber and
vertical-mode bounds support other closures. The incoming balanced
tendency is left unchanged. Select a standard constituent with
`darwinSymbol`, or supply a custom angular `frequency`.

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
  + [`bottomVelocityAtTime`](/classes/forcing/wvpseudotopographicwavegeneration/bottomvelocityattime.html) Evaluate $$g_b=\boldsymbol U_{\mathrm{bt}}\boldsymbol{\cdot}\nabla_Hh$$.
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