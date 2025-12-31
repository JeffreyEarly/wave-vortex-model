---
layout: default
title: WVTransform
has_children: false
has_toc: false
mathjax: true
parent: Class documentation
nav_order: 1
---

#  WVTransform

Represents the state of the ocean in terms of energetically orthogonal wave and geostrophic (vortex) solutions


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransform < handle</code></pre></div></div>

## Overview
 
 
The WVTransform subclasses encapsulate data representing the
state of the ocean at a given instant in time. What makes the
WVTransform subclasses special is that the state of the ocean
is represented as energetically independent waves and geostrophic
motions (vortices). These classes can be queried for any ocean state
variable including $$u$$, $$v$$, $$w$$, $$\nho$$, $$p$$, but also
Ertel PV, relative vorticity, or custom defined state variables.
 
The WVTransform is an abstract class and as such you must
instatiate one of the concrete subclasses,
 
+ `WVTransformConstantStratification`
+ `WVTransformHydrostatic`
+ `WVTransformSingleMode`
 
                     



## Topics
+ Initialization
  + [`waveVortexTransformFromFile`](/classes/wvtransform/wavevortextransformfromfile.html) Initialize a WVTransform instance from an existing file
  + [`waveVortexTransformWithDoubleResolution`](/classes/wvtransform/wavevortextransformwithdoubleresolution.html) create a new WVTransform with double resolution
+ Domain attributes
+ Initial Conditions
  + [`addRandomFlow`](/classes/wvtransform/addrandomflow.html) add randomized flow to the existing state
  + [`addUVEta`](/classes/wvtransform/adduveta.html) add $$(u,v,\eta)$$ to the existing values
  + [`initFromNetCDFFile`](/classes/wvtransform/initfromnetcdffile.html) initialize the flow from a NetCDF file
  + [`initWithRandomFlow`](/classes/wvtransform/initwithrandomflow.html) initialize with a random flow state
  + [`initWithUVEta`](/classes/wvtransform/initwithuveta.html) initialize with fluid variables $$(u,v,\eta)$$
  + [`initWithUVRho`](/classes/wvtransform/initwithuvrho.html) initialize with fluid variables $$(u,v,\rho)$$
  + Waves
    + [`removeAll`](/classes/wvtransform/removeall.html) removes all energy from the model
+ Energetics
  + [`summarizeEnergyContent`](/classes/wvtransform/summarizeenergycontent.html) displays a summary of the energy content of the fluid
  + [`summarizeModeEnergy`](/classes/wvtransform/summarizemodeenergy.html) List the most energetic modes
+ Internal
  + [`WVTransform`](/classes/wvtransform/wvtransform.html) initialize a WVTransform instance
  + [`addToVariableCache`](/classes/wvtransform/addtovariablecache.html) add variable to internal cache, in case it is needed again
  + [`clearVariableCacheOfApAmA0DependentVariables`](/classes/wvtransform/clearvariablecacheofapama0dependentvariables.html) clear the internal cache
  + [`clearVariableCacheOfTimeDependentVariables`](/classes/wvtransform/clearvariablecacheoftimedependentvariables.html) clear the internal cache of variables that claim to be time dependent
  + [`defaultOperations`](/classes/wvtransform/defaultoperations.html) return array of WVOperation instances initialized by default
  + [`fetchFromVariableCache`](/classes/wvtransform/fetchfromvariablecache.html) retrieve a set of variables from the internal cache
  + [`performOperation`](/classes/wvtransform/performoperation.html) computes (runs) the operation
  + [`performOperationWithName`](/classes/wvtransform/performoperationwithname.html) computes (runs) the operation
+ Flow components
  + [`addFlowComponent`](/classes/wvtransform/addflowcomponent.html) add a flow component
  + [`addPrimaryFlowComponent`](/classes/wvtransform/addprimaryflowcomponent.html) add a primary flow component, automatically added to the flow
  + [`flowComponentWithName`](/classes/wvtransform/flowcomponentwithname.html) retrieve a WVFlowComponent by name
  + [`primaryFlowComponentWithName`](/classes/wvtransform/primaryflowcomponentwithname.html) retrieve a WVPrimaryFlowComponent by name
+ Utility function
  + [`spectralVariableWithResolution`](/classes/wvtransform/spectralvariablewithresolution.html) create a new variable with different resolution
  + Metadata
    + [`addOperation`](/classes/wvtransform/addoperation.html) add a WVOperation
    + [`flowComponentNames`](/classes/wvtransform/flowcomponentnames.html) retrieve the names of all available variables
    + [`forcingNames`](/classes/wvtransform/forcingnames.html) retrieve the names of all available variables. This preserves
    + [`operationWithName`](/classes/wvtransform/operationwithname.html) retrieve a WVOperation by name
    + [`primaryFlowComponentNames`](/classes/wvtransform/primaryflowcomponentnames.html) retrieve the names of all available variables
    + [`removeOperation`](/classes/wvtransform/removeoperation.html) remove an existing WVOperation
+ Write to file
  + [`concatenateVariablesAlongTimeDimension`](/classes/wvtransform/concatenatevariablesalongtimedimension.html) Concatenate variables along the time dimension
  + [`createNetCDFFileForTimeStepOutput`](/classes/wvtransform/createnetcdffilefortimestepoutput.html) Output the `WVTransform` to file with variable time dimension
  + [`writeToFile`](/classes/wvtransform/writetofile.html) Write this instance to NetCDF file.
+ Operations
  + Transformations
    + [`convertFromWavenumberToFrequency`](/classes/wvtransform/convertfromwavenumbertofrequency.html) Summary
    + [`transformUVEtaToWaveVortex`](/classes/wvtransform/transformuvetatowavevortex.html) transform fluid variables $$(u,v,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
    + [`transformWaveVortexToUVWEta`](/classes/wvtransform/transformwavevortextouvweta.html) transform wave-vortex coefficients $$(A_+,A_-,A_0)$$ to fluid variables $$(u,v,\eta)$$.
+ Nonlinear flux and energy transfers
  + [`energyFluxFromNonlinearFlux`](/classes/wvtransform/energyfluxfromnonlinearflux.html) converts nonlinear flux into energy flux
  + [`enstrophyFluxFromNonlinearFlux`](/classes/wvtransform/enstrophyfluxfromnonlinearflux.html) converts nonlinear flux into enstrophy flux
  + [`nonlinearFluxForFlowComponents`](/classes/wvtransform/nonlinearfluxforflowcomponents.html) returns the flux of each coefficient as determined by the nonlinear flux operation
  + [`nonlinearFluxWithGradientMasks`](/classes/wvtransform/nonlinearfluxwithgradientmasks.html) returns the flux of each coefficient as determined by the nonlinear flux operation
  + [`nonlinearFluxWithMask`](/classes/wvtransform/nonlinearfluxwithmask.html) returns the flux of each coefficient as determined by the nonlinear flux
+ Developer
  + [`propertyAnnotationsForTransform`](/classes/wvtransform/propertyannotationsfortransform.html) return array of CAPropertyAnnotations for the WVTransform
+ State Variables
  + [`variableAtPositionWithName`](/classes/wvtransform/variableatpositionwithname.html) Primary method for accessing the dynamical variables on the at any
  + [`variableWithName`](/classes/wvtransform/variablewithname.html) Primary method for accessing the dynamical variables
+ Other
  + [`A0`](/classes/wvtransform/a0.html) geostrophic coefficients at reference time t0 (m)
  + [`A0_KE_factor`](/classes/wvtransform/a0_ke_factor.html) 
  + [`A0_PE_factor`](/classes/wvtransform/a0_pe_factor.html) 
  + [`A0_Psi_factor`](/classes/wvtransform/a0_psi_factor.html) 
  + [`A0_QGPV_factor`](/classes/wvtransform/a0_qgpv_factor.html) 
  + [`A0_TE_factor`](/classes/wvtransform/a0_te_factor.html) 
  + [`A0_TZ_factor`](/classes/wvtransform/a0_tz_factor.html) 
  + [`Am`](/classes/wvtransform/am.html) negative wave coefficients at reference time t0 (m/s)
  + [`Ap`](/classes/wvtransform/ap.html) positive wave coefficients at reference time t0 (m/s)
  + [`Apm_TE_factor`](/classes/wvtransform/apm_te_factor.html) 
  + [`addForcing`](/classes/wvtransform/addforcing.html) 
  + [`classDefinedOperationForKnownVariable`](/classes/wvtransform/classdefinedoperationforknownvariable.html) This is one of two functions that returns operations for computing
  + [`flowComponentNameMap`](/classes/wvtransform/flowcomponentnamemap.html) 
  + [`flowComponents`](/classes/wvtransform/flowcomponents.html) 
  + [`forcing`](/classes/wvtransform/forcing.html) 
  + [`forcingNameMap`](/classes/wvtransform/forcingnamemap.html) 
  + [`forcingType`](/classes/wvtransform/forcingtype.html) 
  + [`forcingWithName`](/classes/wvtransform/forcingwithname.html) 
  + [`hasClosure`](/classes/wvtransform/hasclosure.html) 
  + [`hasForcingWithName`](/classes/wvtransform/hasforcingwithname.html) 
  + [`hasMeanPressureDifference`](/classes/wvtransform/hasmeanpressuredifference.html) checks if there is a non-zero mean pressure difference between the top and bottom of the fluid
  + [`hasPVComponent`](/classes/wvtransform/haspvcomponent.html) 
  + [`hasVariableWithName`](/classes/wvtransform/hasvariablewithname.html) 
  + [`hasWaveComponent`](/classes/wvtransform/haswavecomponent.html) 
  + [`initForcingFromNetCDFFile`](/classes/wvtransform/initforcingfromnetcdffile.html) forcingGroupName = join( [string(class(self)),"forcing"],"-");
  + [`isHydrostatic`](/classes/wvtransform/ishydrostatic.html) 
  + [`nFluxedComponents`](/classes/wvtransform/nfluxedcomponents.html) 
  + [`nonlinearFlux`](/classes/wvtransform/nonlinearflux.html) 
  + [`operationForKnownVariable`](/classes/wvtransform/operationforknownvariable.html) This is one of two functions that returns operations for computing
  + [`operationNameMap`](/classes/wvtransform/operationnamemap.html) 
  + [`operationVariableNameMap`](/classes/wvtransform/operationvariablenamemap.html) 
  + [`optimizedTransformsForFlowComponent`](/classes/wvtransform/optimizedtransformsforflowcomponent.html) returns optimized transforms that avoid unnecessary computation
  + [`primaryFlowComponentNameMap`](/classes/wvtransform/primaryflowcomponentnamemap.html) 
  + [`primaryFlowComponents`](/classes/wvtransform/primaryflowcomponents.html) 
  + [`propertyAnnotationForKnownVariable`](/classes/wvtransform/propertyannotationforknownvariable.html) This is one of two functions that returns operations for computing
  + [`removeAllForcing`](/classes/wvtransform/removeallforcing.html) 
  + [`removeForcing`](/classes/wvtransform/removeforcing.html) 
  + [`restoreForcingAmplitudes`](/classes/wvtransform/restoreforcingamplitudes.html) 
  + [`rk4NonlinearFlux`](/classes/wvtransform/rk4nonlinearflux.html) 
  + [`rk4NonlinearFluxForFlowComponents`](/classes/wvtransform/rk4nonlinearfluxforflowcomponents.html) 
  + [`setForcing`](/classes/wvtransform/setforcing.html) 
  + [`spatialDimensionNames`](/classes/wvtransform/spatialdimensionnames.html) 
  + [`spatialFluxForcing`](/classes/wvtransform/spatialfluxforcing.html) 
  + [`spectralAmplitudeForcing`](/classes/wvtransform/spectralamplitudeforcing.html) 
  + [`spectralDimensionNames`](/classes/wvtransform/spectraldimensionnames.html) 
  + [`spectralFluxForcing`](/classes/wvtransform/spectralfluxforcing.html) 
  + [`summarizeDegreesOfFreedom`](/classes/wvtransform/summarizedegreesoffreedom.html) 
  + [`summarizeFlowComponents`](/classes/wvtransform/summarizeflowcomponents.html) 
  + [`summarizeForcing`](/classes/wvtransform/summarizeforcing.html) 
  + [`summarizeVariables`](/classes/wvtransform/summarizevariables.html) 
  + [`t`](/classes/wvtransform/t.html) 
  + [`t0`](/classes/wvtransform/t0.html) 
  + [`timeDependentVariablesNameMap`](/classes/wvtransform/timedependentvariablesnamemap.html) 
  + [`totalEnergy`](/classes/wvtransform/totalenergy.html) 
  + [`totalEnergyOfFlowComponent`](/classes/wvtransform/totalenergyofflowcomponent.html) 
  + [`totalEnergySpatiallyIntegrated`](/classes/wvtransform/totalenergyspatiallyintegrated.html) 
  + [`totalFlowComponent`](/classes/wvtransform/totalflowcomponent.html) 
  + [`transformFromSpatialDomainWithFg`](/classes/wvtransform/transformfromspatialdomainwithfg.html) Required for transformUVEtaToWaveVortex 
  + [`transformFromSpatialDomainWithGg`](/classes/wvtransform/transformfromspatialdomainwithgg.html) 
  + [`transformToSpatialDomainWithF`](/classes/wvtransform/transformtospatialdomainwithf.html) Required for transformWaveVortexToUVEta
  + [`transformToSpatialDomainWithFAllDerivatives`](/classes/wvtransform/transformtospatialdomainwithfallderivatives.html) 
  + [`transformToSpatialDomainWithG`](/classes/wvtransform/transformtospatialdomainwithg.html) 
  + [`transformToSpatialDomainWithGAllDerivatives`](/classes/wvtransform/transformtospatialdomainwithgallderivatives.html) 
  + [`updateDependentVariablesNameMap`](/classes/wvtransform/updatedependentvariablesnamemap.html) 
  + [`variableCache`](/classes/wvtransform/variablecache.html) 
  + [`variableNames`](/classes/wvtransform/variablenames.html) 
  + [`version`](/classes/wvtransform/version.html) 
  + [`waveVortexTransformWithResolution`](/classes/wvtransform/wavevortextransformwithresolution.html) 
  + [`wvCoefficientDependentVariablesNameMap`](/classes/wvtransform/wvcoefficientdependentvariablesnamemap.html) 


---