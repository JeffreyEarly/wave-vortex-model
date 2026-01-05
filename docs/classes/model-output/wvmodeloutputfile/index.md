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

A WVModelOutputFile represents a file to be written to disk and has one or more output groups


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVModelOutputFile < handle</code></pre></div></div>

## Overview
 
A `WVModelOutputFile` represents a file to be written to disk, that
may or may not have been created yet, depending on the model time.
The `ncfile` property therefore may be empty if a NetCDF file is not
yet created for writing.
 
A `WVModelOutputFile` holds onto one or more output groups, instances
of `WVModelOutputGroup`, and internally they orchestrate pausing the
model and writing to groups
 
### Usage
 
You probably do not ever need to initialize a WVModelOutputFile
directly, but instead should use the convenience method defined in
`WVModel`,
 
```matlab
outputFile = model.addNewOutputFile("myfile.nc");
```
 
At this stage the file contains no output groups and will not write
anything to file. You can now add output groups to the file. Most
users will want to simply use
 
```matlab
outputFile = model.createNetCDFFileForModelOutput("myfile.nc",outputInterval=86400);
```
 
which will additionally add the evenly-spaced output group and record
the wave-vortex coefficients.
 
 
     



## Topics
+ Properties
  + [`didInitializeStorage`](/classes/model-output/wvmodeloutputfile/didinitializestorage.html) boolean indicating whether or not the internal structure of the NetCDF file has been created
  + [`filename`](/classes/model-output/wvmodeloutputfile/filename.html) name of the current (or future) NetCDF file
  + [`model`](/classes/model-output/wvmodeloutputfile/model.html) reference to the WVModel being used
  + [`ncfile`](/classes/model-output/wvmodeloutputfile/ncfile.html) reference to the NetCDFFile being used for model output
  + [`outputGroups`](/classes/model-output/wvmodeloutputfile/outputgroups.html) array of `WVModelOutputGroup`s that will be written to file
  + [`path`](/classes/model-output/wvmodeloutputfile/path.html) current (or future) path of the NetCDF file
  + [`tInitialize`](/classes/model-output/wvmodeloutputfile/tinitialize.html) time at which the NetCDF file will be created
  + [`wvt`](/classes/model-output/wvmodeloutputfile/wvt.html) pass-through of the wvt instance
+ Internal
  + [`closeNetCDFFile`](/classes/model-output/wvmodeloutputfile/closenetcdffile.html) closes the netcdf file after informing the output groups
  + [`initializeOutputFile`](/classes/model-output/wvmodeloutputfile/initializeoutputfile.html) tells the output groups to initialize themselves in the NetCDF file
  + [`observingSystemWillWriteWaveVortexCoefficients`](/classes/model-output/wvmodeloutputfile/observingsystemwillwritewavevortexcoefficients.html) A simple check to see if one of the observing systems will be writing wave-vortex coefficients
  + [`outputTimesForIntegrationPeriod`](/classes/model-output/wvmodeloutputfile/outputtimesforintegrationperiod.html) returns a unique, ordered array of the aggregate output times during the requested integration period.
  + [`recordNetCDFFileHistory`](/classes/model-output/wvmodeloutputfile/recordnetcdffilehistory.html) tells the output groups to log this time step in the NetCDF history
  + [`writeTimeStepToOutputFile`](/classes/model-output/wvmodeloutputfile/writetimesteptooutputfile.html) tells the output groups to write data at time t
+ Initialization
  + [`WVModelOutputFile`](/classes/model-output/wvmodeloutputfile/wvmodeloutputfile.html) initialize a WVModelOutputFile
  + [`modelOutputFileFromFile`](/classes/model-output/wvmodeloutputfile/modeloutputfilefromfile.html) create a WVModelOutputFile from an existing NetCDFFile
+ Output groups
  + [`addNewEvenlySpacedOutputGroup`](/classes/model-output/wvmodeloutputfile/addnewevenlyspacedoutputgroup.html) add an evenly-spaced output group to this file
  + [`addObservingSystem`](/classes/model-output/wvmodeloutputfile/addobservingsystem.html) add an observing system to the ouput group (if there is only one group)
  + [`addOutputGroup`](/classes/model-output/wvmodeloutputfile/addoutputgroup.html) add an output group to this file
  + [`outputGroupNames`](/classes/model-output/wvmodeloutputfile/outputgroupnames.html) retrieve the names of all output group names
  + [`outputGroupWithName`](/classes/model-output/wvmodeloutputfile/outputgroupwithname.html) retrieve a WVModelOutputGroup by name


---