---
layout: default
title: WVObservingSystem
has_children: false
has_toc: false
mathjax: true
parent: Observing systems
grand_parent: Class documentation
nav_order: 1
---

#  WVObservingSystem

Observe or integrate additional state alongside a WVModel.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVObservingSystem < handle</code></pre></div></div>

## Overview

`WVObservingSystem` is the base class for Eulerian fields,
wave-vortex coefficients, particles, moorings, and tracers. An
observing system belongs to one model. Systems with flux components
participate in numerical integration; other systems sample model
state when requested or written to output.




## Topics
+ Create an observing system
  + [`WVObservingSystem`](/classes/observing-systems/wvobservingsystem/wvobservingsystem.html) Initialize an observing system for a model.
+ Inspect observed state
  + [`description`](/classes/observing-systems/wvobservingsystem/description.html)
  + [`model`](/classes/observing-systems/wvobservingsystem/model.html) reference to the WVModel being used
  + [`name`](/classes/observing-systems/wvobservingsystem/name.html) of the observing system
  + [`wvt`](/classes/observing-systems/wvobservingsystem/wvt.html) reference to the WVModel being used
+ Advance the observing system
  + [`fluxAtTime`](/classes/observing-systems/wvobservingsystem/fluxattime.html) return a cell array of the flux of the variables being
  + [`initialConditions`](/classes/observing-systems/wvobservingsystem/initialconditions.html) return a cell array of variables that need to be integrated


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Observing-system internals
  + [`absErrorTolerance`](/classes/observing-systems/wvobservingsystem/abserrortolerance.html) return a cell array of the absolute tolerances of the
  + [`updateIntegratorValues`](/classes/observing-systems/wvobservingsystem/updateintegratorvalues.html) passes updated values of the variables being integrated.
+ Observing-system persistence
  + [`initializeStorage`](/classes/observing-systems/wvobservingsystem/initializestorage.html) called once to allow the observing system to initialize its storage space in the NetCDFGroup
  + [`observingSystemFromGroup`](/classes/observing-systems/wvobservingsystem/observingsystemfromgroup.html) initialize a WVObservingSystem instance from NetCDF file
  + [`writeTimeStepToFile`](/classes/observing-systems/wvobservingsystem/writetimesteptofile.html) called at each time for the observing system to write to file
+ Observer integration
  + [`lengthOfFluxComponents`](/classes/observing-systems/wvobservingsystem/lengthoffluxcomponents.html) return an array containing the numel of each flux component.
  + [`nFluxComponents`](/classes/observing-systems/wvobservingsystem/nfluxcomponents.html) number of components that need to be integrated in time.


---