---
layout: default
title: WVModelOutputGroup
has_children: false
has_toc: false
mathjax: true
parent: Model output
grand_parent: Class documentation
nav_order: 2
---

#  WVModelOutputGroup

A WVModelOutputGroup represents a group of observing system to be written to file at particular output times


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVModelOutputFile < handle</code></pre></div></div>

## Overview
 
A `WVModelOutputGroup` encapsulates a netcdf group with particular
output times `t`; it has one or more observing systems that get written to the group at those times.
 
The simplest output group is the `WVModelOutputGroupEvenlySpaced`
which, as the name suggests, writes outputs at an evenly spaced
interval.
 
The reason for this abstraction is that some observing systems do not
have evenly spaced output intervals, e.g., the
[AlongTrackSimulator](https://satmapkit.github.io/AlongTrackSimulator/),
and it is often the case that one might want to sample the model for
a short interval at higher frequency, e.g., sampling a mooring at
high frequency to resolve the buoyancy frequency, or running a tracer
experiment for 24 hours in the middle of a long model run.
 

         



## Topics
+ Properties
  + [`didInitializeStorage`](/classes/model-output/wvmodeloutputgroup/didinitializestorage.html) boolean indicating whether or not the internal structure of the NetCDF file has been created
  + [`model`](/classes/model-output/wvmodeloutputgroup/model.html) Reference to the WVModel being used
  + [`name`](/classes/model-output/wvmodeloutputgroup/name.html) of the current (or future) group in the NetCDF file
+ Observing systems
  + [`addObservingSystem`](/classes/model-output/wvmodeloutputgroup/addobservingsystem.html) add an observing system to this file
  + [`observingSystemWithName`](/classes/model-output/wvmodeloutputgroup/observingsystemwithname.html) retrieve an observing system by name
  + [`observingSystems`](/classes/model-output/wvmodeloutputgroup/observingsystems.html) array of WVObservingSystem that will be written to the group
  + [`removeObservingSystem`](/classes/model-output/wvmodeloutputgroup/removeobservingsystem.html) remove an observing system to this file
+ Required subclass overrides
  + [`outputTimesForIntegrationPeriod`](/classes/model-output/wvmodeloutputgroup/outputtimesforintegrationperiod.html) returns a unique, ordered array of the aggregate output times during the requested integration period.
+ Internal
  + [`closeNetCDFFile`](/classes/model-output/wvmodeloutputgroup/closenetcdffile.html) notification that the NetCDF file will close
  + [`initObservingSystemsFromGroup`](/classes/model-output/wvmodeloutputgroup/initobservingsystemsfromgroup.html) asks the output group to load the observing systems in the NetCDF file
  + [`initializeOutputGroup`](/classes/model-output/wvmodeloutputgroup/initializeoutputgroup.html) initializes a new output group in the NetCDF file
  + [`recordNetCDFFileHistory`](/classes/model-output/wvmodeloutputgroup/recordnetcdffilehistory.html) losg this time step in the NetCDF history
  + [`writeTimeStepToNetCDFFile`](/classes/model-output/wvmodeloutputgroup/writetimesteptonetcdffile.html) writes data at time t
+ Initialization
  + [`WVModelOutputGroup`](/classes/model-output/wvmodeloutputgroup/wvmodeloutputgroup.html) initialize a WVModelOutputGroup
  + [`modelOutputGroupFromGroup`](/classes/model-output/wvmodeloutputgroup/modeloutputgroupfromgroup.html) initialize a WVModelOutputGroup instance from NetCDF file
+ Writing to NetCDF files
  + [`group`](/classes/model-output/wvmodeloutputgroup/group.html) Reference to the NetCDFGroup being used for model output
+ Integration
  + [`incrementsWrittenToGroup`](/classes/model-output/wvmodeloutputgroup/incrementswrittentogroup.html) output index of the current/most recent step.
  + [`timeOfLastIncrementWrittenToGroup`](/classes/model-output/wvmodeloutputgroup/timeoflastincrementwrittentogroup.html) output index of the current/most recent step.


---