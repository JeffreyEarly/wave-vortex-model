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

Add forcing or dissipation to a wave-vortex transform.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVForcing < handle</code></pre></div></div>

## Overview

`WVForcing` is the abstract base class for forcing and closure objects
attached to a `WVTransform`. Use one of the supplied subclasses or
implement this interface for a custom forcing.

Forcing is applied in three stages. Physical-space forcing contributes
tendencies to $$(u,v,\eta)$$ for hydrostatic flow or
$$(u,v,w,\eta)$$ for nonhydrostatic flow. Those tendencies are projected
into wave-vortex space before spectral forcing contributes directly to
$$(F_+,F_-,F_0)$$. Spectral-amplitude forcing may then update `Ap`, `Am`,
and `A0` directly. Potential-vorticity variants contribute only to the
zero-frequency tendency or amplitude.

A custom subclass declares its stages with `forcingType` and overrides
the corresponding method, such as `addHydrostaticSpatialForcing`,
`addNonhydrostaticSpatialForcing`, `addSpectralForcing`, or
`setSpectralAmplitude`. The `forcingType` property documents the complete
mapping, including the potential-vorticity variants.

`WVTransform.addForcing` registers forcing objects, orders compatible
contributions by priority, and exposes their energy transfers through
the transform diagnostics.




## Topics
+ Create forcing and closures
  + [`WVForcing`](/classes/forcing/wvforcing/wvforcing.html) create a new nonlinear flux operation
+ Inspect forcing configuration
  + [`forcingType`](/classes/forcing/wvforcing/forcingtype.html) Array of supported forcing types
  + [`isClosure`](/classes/forcing/wvforcing/isclosure.html) boolean indicating that this forcing is a turbulence closure
  + [`name`](/classes/forcing/wvforcing/name.html) used to register this forcing with its transform.
  + [`priority`](/classes/forcing/wvforcing/priority.html) determines the order in which the WVForcing will be
+ Convert forcing resolution
  + [`forcingWithResolutionOfTransform`](/classes/forcing/wvforcing/forcingwithresolutionoftransform.html) create a new WVForcing with a new resolution
+ Configure forcing
  + [`setPotentialVorticitySpectralAmplitude`](/classes/forcing/wvforcing/setpotentialvorticityspectralamplitude.html)
  + [`setPotentialVorticitySpectralForcing`](/classes/forcing/wvforcing/setpotentialvorticityspectralforcing.html)
  + [`setSpectralAmplitude`](/classes/forcing/wvforcing/setspectralamplitude.html)
  + [`setSpectralForcing`](/classes/forcing/wvforcing/setspectralforcing.html)


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing evaluation
  + [`addHydrostaticSpatialForcing`](/classes/forcing/wvforcing/addhydrostaticspatialforcing.html)
  + [`addNonhydrostaticSpatialForcing`](/classes/forcing/wvforcing/addnonhydrostaticspatialforcing.html)
  + [`addPotentialVorticitySpatialForcing`](/classes/forcing/wvforcing/addpotentialvorticityspatialforcing.html)
  + [`addPotentialVorticitySpectralForcing`](/classes/forcing/wvforcing/addpotentialvorticityspectralforcing.html)
  + [`addSpectralForcing`](/classes/forcing/wvforcing/addspectralforcing.html)
  + [`spatialFluxTypes`](/classes/forcing/wvforcing/spatialfluxtypes.html)
  + [`spectralAmplitudeTypes`](/classes/forcing/wvforcing/spectralamplitudetypes.html)
  + [`spectralFluxTypes`](/classes/forcing/wvforcing/spectralfluxtypes.html)
+ Forcing internals
  + [`didGetRemovedFromTransform`](/classes/forcing/wvforcing/didgetremovedfromtransform.html)
  + [`wvt`](/classes/forcing/wvforcing/wvt.html)
+ Forcing persistence
  + [`forcingFromGroup`](/classes/forcing/wvforcing/forcingfromgroup.html) initialize a WVForcing instance from NetCDF file


---