---
layout: default
title: WVForcing
has_children: false
has_toc: false
mathjax: true
parent: Forcing
nav_order: 1
---

#  WVForcing

Computes a forcing


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVForcing < handle</code></pre></div></div>

## Overview

orcing is an abstract class that defines how forcing gets added to
VTransform. You can use one the built-in forcing operations, or
e your own.

cing is applied at two stages:
in the spatial domain to
1. non-hydrostatic flow d/dt(u,v,w,eta) = (Fu,Fv,Fw,Feta) or
1. hydrostatic flow d/dt(u,v,eta) = (Fu,Fv,Feta)  and
in the spectral domain to d/dt(Ap,Am,A0) = (Fp,Fm,F0)

h WVForcingFluxOperation must choose one of the two options and
rride either,
[Fu, Fv, Fw, Feta] = addSpatialForcing(wvt, Fu, Fv, Fw, Feta) or,
[Fp, Fm, F0] = addSpectralForcing( wvt, Fp, Fm, F0)

ardless of which method is chosen, the energy flux from the forcing
 always be deduced at each moment in time.




## Topics
+ Initialization
  + [`WVForcing`](/classes/forcing/wvforcing/wvforcing.html) create a new nonlinear flux operation
  + [`forcingFromGroup`](/classes/forcing/wvforcing/forcingfromgroup.html) initialize a WVForcing instance from NetCDF file
  + [`forcingWithResolutionOfTransform`](/classes/forcing/wvforcing/forcingwithresolutionoftransform.html) create a new WVForcing with a new resolution
+ Properties
  + [`forcingType`](/classes/forcing/wvforcing/forcingtype.html) Array of supported forcing types
  + [`isClosure`](/classes/forcing/wvforcing/isclosure.html) boolean indicating that this forcing is a turbulence closure
  + [`name`](/classes/forcing/wvforcing/name.html) boolean indicating this class implements addHydrostaticSpatialForcing
+ Other
  + [`addHydrostaticSpatialForcing`](/classes/forcing/wvforcing/addhydrostaticspatialforcing.html)
  + [`addNonhydrostaticSpatialForcing`](/classes/forcing/wvforcing/addnonhydrostaticspatialforcing.html)
  + [`addPotentialVorticitySpatialForcing`](/classes/forcing/wvforcing/addpotentialvorticityspatialforcing.html)
  + [`addPotentialVorticitySpectralForcing`](/classes/forcing/wvforcing/addpotentialvorticityspectralforcing.html)
  + [`addSpectralForcing`](/classes/forcing/wvforcing/addspectralforcing.html)
  + [`didGetRemovedFromTransform`](/classes/forcing/wvforcing/didgetremovedfromtransform.html)
  + [`priority`](/classes/forcing/wvforcing/priority.html) determines the order in which the WVForcing will be
  + [`setPotentialVorticitySpectralAmplitude`](/classes/forcing/wvforcing/setpotentialvorticityspectralamplitude.html)
  + [`setPotentialVorticitySpectralForcing`](/classes/forcing/wvforcing/setpotentialvorticityspectralforcing.html)
  + [`setSpectralAmplitude`](/classes/forcing/wvforcing/setspectralamplitude.html)
  + [`setSpectralForcing`](/classes/forcing/wvforcing/setspectralforcing.html)
  + [`spatialFluxTypes`](/classes/forcing/wvforcing/spatialfluxtypes.html)
  + [`spectralAmplitudeTypes`](/classes/forcing/wvforcing/spectralamplitudetypes.html)
  + [`spectralFluxTypes`](/classes/forcing/wvforcing/spectralfluxtypes.html)
  + [`wvt`](/classes/forcing/wvforcing/wvt.html)


---