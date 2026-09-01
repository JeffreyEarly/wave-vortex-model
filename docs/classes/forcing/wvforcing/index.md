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

`WVForcing` is the base class for right-hand-side and closure objects
attached to a `WVTransform`. Use one of the supplied subclasses or
subclass this interface to implement a custom forcing. Each instance
belongs to the transform supplied at construction and is registered by
its unique `name` through `WVTransform.addForcing`.

Forcing is applied in three stages. Physical-space forcing contributes
tendencies to $$(u,v,\eta)$$ for hydrostatic flow or
$$(u,v,w,\eta)$$ for nonhydrostatic flow. Those tendencies are projected
into wave-vortex space before spectral forcing contributes directly to
$$(F_+,F_-,F_0)$$. Spectral-amplitude forcing may then update `Ap`, `Am`,
and `A0` directly. Legacy potential-vorticity variants contribute only
to the zero-frequency tendency or amplitude. QG-state spatial forcing
contributes both an interior QGPV tendency and active-endpoint anomaly
tendencies before the transform projects them into coefficient space;
QG spectral forcing then modifies the family-keyed coefficient tendency.

A custom subclass declares one or more stages with `forcingType` and
overrides the corresponding evaluation methods. Spatial forcing is
evaluated before projection, spectral forcing is evaluated after
projection, and spectral-amplitude forcing is evaluated last. Within
each stage, smaller `priority` values are evaluated first.

`WVTransform.addForcing` registers forcing objects, orders compatible
contributions by priority, and exposes their energy transfers through
the transform diagnostics.




## Topics
+ Create the forcing
  + [`WVForcing`](/classes/forcing/wvforcing/wvforcing.html) Initialize the base state for a forcing subclass.
+ Inspect forcing configuration
  + [`wvt`](/classes/forcing/wvforcing/wvt.html) Transform to which this forcing belongs.
  + [`name`](/classes/forcing/wvforcing/name.html) used to register this forcing with its transform.
  + [`forcingType`](/classes/forcing/wvforcing/forcingtype.html) Evaluation stages implemented by this forcing.
  + [`isClosure`](/classes/forcing/wvforcing/isclosure.html) Whether this forcing is a small-scale closure.
  + [`priority`](/classes/forcing/wvforcing/priority.html) Order within a forcing stage, from 0 first to 255 last.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Implement forcing evaluation
  + [`addHydrostaticSpatialForcing`](/classes/forcing/wvforcing/addhydrostaticspatialforcing.html) Add hydrostatic physical-space tendencies.
  + [`addNonhydrostaticSpatialForcing`](/classes/forcing/wvforcing/addnonhydrostaticspatialforcing.html) Add nonhydrostatic physical-space tendencies.
  + [`addPotentialVorticitySpatialForcing`](/classes/forcing/wvforcing/addpotentialvorticityspatialforcing.html) Add a physical-space QGPV tendency.
  + [`addPotentialVorticitySpectralForcing`](/classes/forcing/wvforcing/addpotentialvorticityspectralforcing.html) Add a spectral QGPV tendency.
  + [`addSpectralForcing`](/classes/forcing/wvforcing/addspectralforcing.html) Add wave-vortex coefficient tendencies in spectral space.
  + [`setPotentialVorticitySpectralAmplitude`](/classes/forcing/wvforcing/setpotentialvorticityspectralamplitude.html) Restore selected QG coefficients after a model step.
  + [`setPotentialVorticitySpectralForcing`](/classes/forcing/wvforcing/setpotentialvorticityspectralforcing.html) Modify QGPV tendencies for a spectral-amplitude constraint.
  + [`setSpectralAmplitude`](/classes/forcing/wvforcing/setspectralamplitude.html) Restore selected wave-vortex coefficients after a model step.
  + [`setSpectralForcing`](/classes/forcing/wvforcing/setspectralforcing.html) Modify tendencies for a spectral-amplitude constraint.
  + [`spatialFluxTypes`](/classes/forcing/wvforcing/spatialfluxtypes.html) Return the physical-space forcing types.
  + [`spectralAmplitudeTypes`](/classes/forcing/wvforcing/spectralamplitudetypes.html) Return the spectral-amplitude forcing types.
  + [`spectralFluxTypes`](/classes/forcing/wvforcing/spectralfluxtypes.html) Return the spectral-tendency forcing types.
+ Convert forcing resolution
  + [`forcingWithResolutionOfTransform`](/classes/forcing/wvforcing/forcingwithresolutionoftransform.html) Rebuild a forcing for a compatible transform resolution.
+ Forcing persistence
  + [`forcingFromGroup`](/classes/forcing/wvforcing/forcingfromgroup.html) Restore a concrete forcing from a NetCDF group.
+ Forcing internals
  + [`addQuasigeostrophicSpatialForcing`](/classes/forcing/wvforcing/addquasigeostrophicspatialforcing.html) Add interior and active-endpoint QG physical-space tendencies.
  + [`addQuasigeostrophicSpectralForcing`](/classes/forcing/wvforcing/addquasigeostrophicspectralforcing.html) Add a free-surface QG coefficient-family tendency.
  + [`didGetRemovedFromTransform`](/classes/forcing/wvforcing/didgetremovedfromtransform.html) Release resources when a forcing is removed from its transform.
  + [`portableImplementationContract`](/classes/forcing/wvforcing/portableimplementationcontract.html) Describe availability of the paired portable C++ implementation.


---