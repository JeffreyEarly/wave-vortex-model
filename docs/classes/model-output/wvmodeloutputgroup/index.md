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

Schedule observing systems into one NetCDF output group.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVModelOutputGroup < handle</code></pre></div></div>

## Overview

A `WVModelOutputGroup` contains one or more observing systems and
defines the model times at which their state is written.

The simplest output group is the
[`WVModelOutputGroupEvenlySpaced`](/classes/model-output/wvmodeloutputgroupevenlyspaced/)
which, as the name suggests, writes outputs at an evenly spaced
interval.

Separate groups allow different observing systems to use different
schedules or bounded output windows within the same file. This matters
when an observing system does not sample evenly, such as a satellite
along-track simulator, or when one diagnostic needs a shorter,
higher-frequency window than the rest of a long model run. For example,
a mooring may need to resolve the buoyancy frequency, while a tracer
experiment may run for only 24 hours in the middle of the simulation.

### Usage

```matlab
outputFile = model.addNewOutputFile("myfile.nc");
outputGroup = WVModelOutputGroupEvenlySpaced(model,name="high-temporal-resolution",initialTime=wvt.t,outputInterval=wvt.inertialPeriod/20);
outputFile.addOutputGroup(outputGroup);
```




## Topics
+ Create model output
  + [`WVModelOutputGroup`](/classes/model-output/wvmodeloutputgroup/wvmodeloutputgroup.html) initialize a WVModelOutputGroup
+ Manage output observers
  + [`addObservingSystem`](/classes/model-output/wvmodeloutputgroup/addobservingsystem.html) add an observing system to this file
  + [`initObservingSystemsFromGroup`](/classes/model-output/wvmodeloutputgroup/initobservingsystemsfromgroup.html) asks the output group to load the observing systems in the NetCDF file
  + [`removeObservingSystem`](/classes/model-output/wvmodeloutputgroup/removeobservingsystem.html) remove an observing system to this file
+ Write and close output
  + [`closeNetCDFFile`](/classes/model-output/wvmodeloutputgroup/closenetcdffile.html) notification that the NetCDF file will close
  + [`initializeOutputGroup`](/classes/model-output/wvmodeloutputgroup/initializeoutputgroup.html) initializes a new output group in the NetCDF file
  + [`writeTimeStepToNetCDFFile`](/classes/model-output/wvmodeloutputgroup/writetimesteptonetcdffile.html) writes data at time t


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Output internals
  + [`commitStagedTimeStep`](/classes/model-output/wvmodeloutputgroup/commitstagedtimestep.html) Commit a staged record by writing its finite time coordinate.
  + [`model`](/classes/model-output/wvmodeloutputgroup/model.html) Reference to the WVModel being used
  + [`name`](/classes/model-output/wvmodeloutputgroup/name.html) of the current (or future) group in the NetCDF file
  + [`observingSystemWithName`](/classes/model-output/wvmodeloutputgroup/observingsystemwithname.html) retrieve an observing system by name
  + [`observingSystems`](/classes/model-output/wvmodeloutputgroup/observingsystems.html) array of WVObservingSystem that will be written to the group
+ Output persistence and scheduling
  + [`committedRecordCountForGroup`](/classes/model-output/wvmodeloutputgroup/committedrecordcountforgroup.html) Return the contiguous committed prefix of an output group.
  + [`didInitializeStorage`](/classes/model-output/wvmodeloutputgroup/didinitializestorage.html) boolean indicating whether or not the internal structure of the NetCDF file has been created
  + [`group`](/classes/model-output/wvmodeloutputgroup/group.html) Reference to the NetCDFGroup being used for model output
  + [`incrementsWrittenToGroup`](/classes/model-output/wvmodeloutputgroup/incrementswrittentogroup.html) output index of the current/most recent step.
  + [`modelOutputGroupFromGroup`](/classes/model-output/wvmodeloutputgroup/modeloutputgroupfromgroup.html) initialize a WVModelOutputGroup instance from NetCDF file
  + [`outputTimesForIntegrationPeriod`](/classes/model-output/wvmodeloutputgroup/outputtimesforintegrationperiod.html) returns a unique, ordered array of the aggregate output times during the requested integration period.
  + [`recordNetCDFFileHistory`](/classes/model-output/wvmodeloutputgroup/recordnetcdffilehistory.html) losg this time step in the NetCDF history
  + [`stageTimeStepToNetCDFFile`](/classes/model-output/wvmodeloutputgroup/stagetimesteptonetcdffile.html) Stage one record payload without committing its time coordinate.
  + [`timeOfLastIncrementWrittenToGroup`](/classes/model-output/wvmodeloutputgroup/timeoflastincrementwrittentogroup.html) output index of the current/most recent step.


---