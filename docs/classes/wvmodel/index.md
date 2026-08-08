---
layout: default
title: WVModel
has_children: false
has_toc: false
mathjax: true
parent: Class documentation
nav_order: 2
---

#  WVModel

Integrate a fluid state represented by a WVTransform.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVModel < handle</code></pre></div></div>

## Overview

Construct a transform and use it to initialize the model:
```matlab
wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,9],N0=5.2e-3,latitude=45);
model = WVModel(wvt);
```
By default `WVModel` integrates the transform's nonlinear forcing and
registers its coefficient observing system. Pass
`shouldUseLinearDynamics=true` for analytical linear evolution. Use
`setupIntegrator` to select the Stable fixed or adaptive integrator;
`adaptive-cell` remains Experimental.

Restore a model and its output graph from one restart-capable file:
```matlab
model = WVModel.modelFromFile("SomeFile.nc");
```




## Topics
+ Initialization
  + [`WVModel`](/classes/wvmodel/wvmodel.html) Initialize a model from a WVTransform instance.
  + [`modelFromFile`](/classes/wvmodel/modelfromfile.html) Initialize a model from an existing file
+ Model Properties
  + [`initialTime`](/classes/wvmodel/initialtime.html) Initial model time (seconds)
  + [`isDynamicsLinear`](/classes/wvmodel/isdynamicslinear.html) Whether the model uses analytical linear dynamics.
  + [`summarize`](/classes/wvmodel/summarize.html) Print a summary of integrated systems and output files.
  + [`t`](/classes/wvmodel/t.html) Current model time (seconds)
  + [`wvt`](/classes/wvmodel/wvt.html) WVTransform instance representing the ocean state.
+ Integration
  + [`integrateToTime`](/classes/wvmodel/integratetotime.html) Time step the model forward to the requested time.
  + [`setupIntegrator`](/classes/wvmodel/setupintegrator.html) Customize the time-stepping
+ Particles
  + [`addParticles`](/classes/wvmodel/addparticles.html) Add particles to be advected by the flow.
  + [`drifterPositions`](/classes/wvmodel/drifterpositions.html) Current positions of the drifter particles
  + [`floatPositions`](/classes/wvmodel/floatpositions.html) Returns the positions of the floats at the current time as well as the value of the fields being tracked.
  + [`particlePositions`](/classes/wvmodel/particlepositions.html) Positions and values of tracked fields of particles at the current model time.
  + [`setDrifterPositions`](/classes/wvmodel/setdrifterpositions.html) Set positions of drifter-like particles to be advected.
  + [`setFloatPositions`](/classes/wvmodel/setfloatpositions.html) Set positions of float-like particles to be advected by the model.
+ Tracer
  + [`addTracer`](/classes/wvmodel/addtracer.html) Add a scalar field tracer to be advected by the flow
  + [`tracer`](/classes/wvmodel/tracer.html) Scalar field of the requested tracer at the current model time.
+ Writing to NetCDF files
  + [`addNetCDFOutputVariables`](/classes/wvmodel/addnetcdfoutputvariables.html) Add variables to list of variables to be written to the NetCDF variable during the model run.
  + [`addNewOutputFile`](/classes/wvmodel/addnewoutputfile.html) add a WVModelOutputFile, by passing an output path
  + [`addOutputFile`](/classes/wvmodel/addoutputfile.html) add a WVModelOutputFile, by passing a WVModelOutputFile instance
  + [`createNetCDFFileForModelOutput`](/classes/wvmodel/createnetcdffileformodeloutput.html) Create a NetCDF file for model output
  + [`ncfile`](/classes/wvmodel/ncfile.html) returns the first/primary NetCDF file being written to
  + [`outputFileNames`](/classes/wvmodel/outputfilenames.html) retrieve the names of all output files
  + [`outputFileWithName`](/classes/wvmodel/outputfilewithname.html) retrieve a WVModelOutputFile by name
  + [`outputFiles`](/classes/wvmodel/outputfiles.html) Array of WVModelOutputFile instances
  + [`removeNetCDFOutputVariables`](/classes/wvmodel/removenetcdfoutputvariables.html) Remove variables from the list of variables to be written to the NetCDF variable during the model run.
  + [`setNetCDFOutputVariables`](/classes/wvmodel/setnetcdfoutputvariables.html) Set list of variables to be written to the NetCDF variable during the model run.
+ Integrated (fluxed) observing systems
  + [`addFluxedCoefficients`](/classes/wvmodel/addfluxedcoefficients.html) add the `WVCoefficients` to the fluxed observing systems array
  + [`addFluxedObservingSystem`](/classes/wvmodel/addfluxedobservingsystem.html) add a WVObservingSystem to the fluxed observing systems array
  + [`fluxedObservingSystemWithName`](/classes/wvmodel/fluxedobservingsystemwithname.html) retrieve a WVObservingSystem by name
  + [`removeFluxedObservingSystem`](/classes/wvmodel/removefluxedobservingsystem.html) remove a WVObservingSystem to the fluxed observing systems array
  + [`wvCoefficientFluxedObservingSystem`](/classes/wvmodel/wvcoefficientfluxedobservingsystem.html) return the `WVCoefficients` fluxed observing system
+ Other
  + [`absErrorToleranceCellArray`](/classes/wvmodel/abserrortolerancecellarray.html)
  + [`closeNetCDFFile`](/classes/wvmodel/closenetcdffile.html)
  + [`defaultOutputGroupName`](/classes/wvmodel/defaultoutputgroupname.html)
  + [`didBlowUp`](/classes/wvmodel/didblowup.html)
  + [`didSetupIntegrator`](/classes/wvmodel/didsetupintegrator.html)
  + [`eulerianObservingSystem`](/classes/wvmodel/eulerianobservingsystem.html)
  + [`finalIntegrationTime`](/classes/wvmodel/finalintegrationtime.html) set only during an integration
  + [`fluxAtTimeCellArray`](/classes/wvmodel/fluxattimecellarray.html)
  + [`fluxedObservingSystems`](/classes/wvmodel/fluxedobservingsystems.html)
  + [`indicesForFluxedSystem`](/classes/wvmodel/indicesforfluxedsystem.html)
  + [`initialConditionsCellArray`](/classes/wvmodel/initialconditionscellarray.html)
  + [`integrationCallback`](/classes/wvmodel/integrationcallback.html)
  + [`integrationInformTime`](/classes/wvmodel/integrationinformtime.html)
  + [`integrationLastInformModelTime`](/classes/wvmodel/integrationlastinformmodeltime.html)
  + [`integrationLastInformWallTime`](/classes/wvmodel/integrationlastinformwalltime.html) wall clock, to keep track of the expected integration time
  + [`integrationStartModelTime`](/classes/wvmodel/integrationstartmodeltime.html)
  + [`integrationStartWallTime`](/classes/wvmodel/integrationstartwalltime.html)
  + [`integratorType`](/classes/wvmodel/integratortype.html) Array integrator
  + [`nFluxComponents`](/classes/wvmodel/nfluxcomponents.html)
  + [`nFluxComputations`](/classes/wvmodel/nfluxcomputations.html)
  + [`nFluxComputationsAtLastInform`](/classes/wvmodel/nfluxcomputationsatlastinform.html)
  + [`outputTimesForIntegrationPeriod`](/classes/wvmodel/outputtimesforintegrationperiod.html) This will be called exactly once before an integration
  + [`pseudoIntegrateToTime`](/classes/wvmodel/pseudointegratetotime.html) Time step the model forward linearly
  + [`recomputeIndicesForFluxedSystems`](/classes/wvmodel/recomputeindicesforfluxedsystems.html)
  + [`recordNetCDFFileHistory`](/classes/wvmodel/recordnetcdffilehistory.html)
  + [`shouldShowIntegrationDiagnostics`](/classes/wvmodel/shouldshowintegrationdiagnostics.html)
  + [`showIntegrationFinishDiagnostics`](/classes/wvmodel/showintegrationfinishdiagnostics.html)
  + [`showIntegrationStartDiagnostics`](/classes/wvmodel/showintegrationstartdiagnostics.html)
  + [`showIntegrationTimeDiagnostics`](/classes/wvmodel/showintegrationtimediagnostics.html)
  + [`updateIntegratorValuesFromCellArray`](/classes/wvmodel/updateintegratorvaluesfromcellarray.html) We must set the time here. If we are integrating the
  + [`writeTimeStepToNetCDFFile`](/classes/wvmodel/writetimesteptonetcdffile.html)


---