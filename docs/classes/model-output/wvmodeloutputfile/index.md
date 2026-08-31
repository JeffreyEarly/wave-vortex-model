---
layout: default
title: WVModelOutputFile
has_children: false
has_toc: false
mathjax: true
parent: Model output
grand_parent: Class documentation
nav_order: 1
---

#  WVModelOutputFile

Organize one NetCDF output file for a WVModel.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVModelOutputFile < handle</code></pre></div></div>

## Overview

A `WVModelOutputFile` owns the writable NetCDF handle and one or more
output groups. The file is opened when its first group initializes, so
`ncfile` may be empty before output begins.

Most users create a configured file through `WVModel`:

```matlab
outputFile = model.createNetCDFFileForModelOutput("myfile.nc",outputInterval=86400);
```

This adds an evenly spaced output group containing the wave-vortex
coefficients. For explicit control, first create an empty file
description and then add one or more groups:

```matlab
outputFile = model.addNewOutputFile("myfile.nc");
outputGroup = outputFile.addNewEvenlySpacedOutputGroup( ...
"daily",initialTime=model.t,outputInterval=86400);
```

An empty output file has no schedule and writes nothing until a group is
added. The physical NetCDF file is created lazily at the first scheduled
output time, so `ncfile` remains empty beforehand. Close the file through
the model or output-file facade when writing is complete.




## Topics
+ Create model output
  + [`WVModelOutputFile`](/classes/model-output/wvmodeloutputfile/wvmodeloutputfile.html) initialize a WVModelOutputFile
+ Manage output observers
  + [`addObservingSystem`](/classes/model-output/wvmodeloutputfile/addobservingsystem.html) add an observing system to the ouput group (if there is only one group)
+ Write and close output
  + [`closeNetCDFFile`](/classes/model-output/wvmodeloutputfile/closenetcdffile.html) closes the netcdf file after informing the output groups
  + [`initializeOutputFile`](/classes/model-output/wvmodeloutputfile/initializeoutputfile.html) tells the output groups to initialize themselves in the NetCDF file
  + [`writeTimeStepToOutputFile`](/classes/model-output/wvmodeloutputfile/writetimesteptooutputfile.html) tells the output groups to write data at time t


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Output persistence and scheduling
  + [`addNewEvenlySpacedOutputGroup`](/classes/model-output/wvmodeloutputfile/addnewevenlyspacedoutputgroup.html) add an evenly-spaced output group to this file
  + [`addOutputGroup`](/classes/model-output/wvmodeloutputfile/addoutputgroup.html) add an output group to this file
  + [`didInitializeStorage`](/classes/model-output/wvmodeloutputfile/didinitializestorage.html) boolean indicating whether or not the internal structure of the NetCDF file has been created
  + [`filename`](/classes/model-output/wvmodeloutputfile/filename.html) name of the current (or future) NetCDF file
  + [`modelOutputFileFromFile`](/classes/model-output/wvmodeloutputfile/modeloutputfilefromfile.html) create a WVModelOutputFile from an existing NetCDFFile
  + [`ncfile`](/classes/model-output/wvmodeloutputfile/ncfile.html) reference to the NetCDFFile being used for model output
  + [`outputGroupNames`](/classes/model-output/wvmodeloutputfile/outputgroupnames.html) retrieve the names of all output group names
  + [`outputGroupWithName`](/classes/model-output/wvmodeloutputfile/outputgroupwithname.html) retrieve a WVModelOutputGroup by name
  + [`outputGroups`](/classes/model-output/wvmodeloutputfile/outputgroups.html) array of `WVModelOutputGroup`s that will be written to file
  + [`outputGroupsContainingCompleteCoefficientState`](/classes/model-output/wvmodeloutputfile/outputgroupscontainingcompletecoefficientstate.html) Return output groups containing every physical coefficient family.
  + [`outputTimesForIntegrationPeriod`](/classes/model-output/wvmodeloutputfile/outputtimesforintegrationperiod.html) returns a unique, ordered array of the aggregate output times during the requested integration period.
  + [`recordNetCDFFileHistory`](/classes/model-output/wvmodeloutputfile/recordnetcdffilehistory.html) tells the output groups to log this time step in the NetCDF history
+ Output internals
  + [`model`](/classes/model-output/wvmodeloutputfile/model.html) reference to the WVModel being used
  + [`observingSystemWillWriteWaveVortexCoefficients`](/classes/model-output/wvmodeloutputfile/observingsystemwillwritewavevortexcoefficients.html) A simple check to see if one of the observing systems will be writing wave-vortex coefficients
  + [`path`](/classes/model-output/wvmodeloutputfile/path.html) current (or future) path of the NetCDF file
  + [`tInitialize`](/classes/model-output/wvmodeloutputfile/tinitialize.html) time at which the NetCDF file will be created
  + [`wvt`](/classes/model-output/wvmodeloutputfile/wvt.html) pass-through of the wvt instance


---