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

A WVObservingSystem is an abstract class that defines different ways of observing the model


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVObservingSystem < handle</code></pre></div></div>

## Overview
 
 
 
  
           
  


## Topics
+ Initializing
  + [`WVObservingSystem`](/classes/observing-systems/wvobservingsystem/wvobservingsystem.html) create a new observing system
+ Properties
  + [`model`](/classes/observing-systems/wvobservingsystem/model.html) reference to the WVModel being used
  + [`nFluxComponents`](/classes/observing-systems/wvobservingsystem/nfluxcomponents.html) number of components that need to be integrated in time.
  + [`name`](/classes/observing-systems/wvobservingsystem/name.html) of the observing system
  + [`wvt`](/classes/observing-systems/wvobservingsystem/wvt.html) reference to the WVModel being used
+ Required subclass overrides
  + [`initializeStorage`](/classes/observing-systems/wvobservingsystem/initializestorage.html) called once to allow the observing system to initialize its storage space in the NetCDFGroup
  + [`writeTimeStepToFile`](/classes/observing-systems/wvobservingsystem/writetimesteptofile.html) called at each time for the observing system to write to file
+ Required subclass overrides for integrated (fluxed) components
  + [`absErrorTolerance`](/classes/observing-systems/wvobservingsystem/abserrortolerance.html) return a cell array of the absolute tolerances of the
  + [`fluxAtTime`](/classes/observing-systems/wvobservingsystem/fluxattime.html) return a cell array of the flux of the variables being
  + [`initialConditions`](/classes/observing-systems/wvobservingsystem/initialconditions.html) return a cell array of variables that need to be integrated
  + [`lengthOfFluxComponents`](/classes/observing-systems/wvobservingsystem/lengthoffluxcomponents.html) return an array containing the numel of each flux component.
  + [`updateIntegratorValues`](/classes/observing-systems/wvobservingsystem/updateintegratorvalues.html) passes updated values of the variables being integrated.
+ Initialization
  + [`observingSystemFromGroup`](/classes/observing-systems/wvobservingsystem/observingsystemfromgroup.html) initialize a WVObservingSystem instance from NetCDF file
+ Other
  + [`description`](/classes/observing-systems/wvobservingsystem/description.html) 


---