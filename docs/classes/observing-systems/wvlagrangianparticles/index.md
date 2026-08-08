---
layout: default
title: WVLagrangianParticles
has_children: false
has_toc: false
mathjax: true
parent: Observing systems
grand_parent: Class documentation
nav_order: 3
---

#  WVLagrangianParticles

Track particles and sampled fields through a WVModel velocity field.


---

## Overview

`WVLagrangianParticles` stores periodic horizontal positions, optional
vertical positions, interpolation choices, and fields sampled at each
particle. Model particle facades construct the usual float and drifter
configurations.


## Topics
+ Create an observing system
  + [`WVLagrangianParticles`](/classes/observing-systems/wvlagrangianparticles/wvlagrangianparticles.html) Create a Lagrangian-particle observing system.
+ Inspect observed state
  + [`absToleranceXY`](/classes/observing-systems/wvlagrangianparticles/abstolerancexy.html) absolute tolerance for the adaptive integrator in x-y directions
  + [`absToleranceZ`](/classes/observing-systems/wvlagrangianparticles/abstolerancez.html) absolute tolerance for the adaptive integrator in z direction
  + [`nParticles`](/classes/observing-systems/wvlagrangianparticles/nparticles.html)
  + [`trackedFieldNames`](/classes/observing-systems/wvlagrangianparticles/trackedfieldnames.html) tracked field names
  + [`trackedFields`](/classes/observing-systems/wvlagrangianparticles/trackedfields.html)
  + [`x`](/classes/observing-systems/wvlagrangianparticles/x.html)
  + [`y`](/classes/observing-systems/wvlagrangianparticles/y.html)
  + [`z`](/classes/observing-systems/wvlagrangianparticles/z.html)
+ Advance the observing system
  + [`particlePositions`](/classes/observing-systems/wvlagrangianparticles/particlepositions.html) Positions and values of tracked fields of particles at the current model time.
  + [`updateParticleTrackedFields`](/classes/observing-systems/wvlagrangianparticles/updateparticletrackedfields.html) One special thing we have to do is log the particle


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Observing-system internals
  + [`advectionInterpolation`](/classes/observing-systems/wvlagrangianparticles/advectioninterpolation.html) interpolation method for the advection scheme
  + [`classRequiredPropertyNames`](/classes/observing-systems/wvlagrangianparticles/classrequiredpropertynames.html)
  + [`isXYOnly`](/classes/observing-systems/wvlagrangianparticles/isxyonly.html) whether the advection is only applied in x-y
  + [`trackedFieldNamesCell`](/classes/observing-systems/wvlagrangianparticles/trackedfieldnamescell.html)
  + [`trackedVarInterpolation`](/classes/observing-systems/wvlagrangianparticles/trackedvarinterpolation.html) interpolation method for the tracked fields


---