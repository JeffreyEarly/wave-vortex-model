---
layout: default
title: WVTransform
has_children: false
has_toc: false
mathjax: true
parent: Transforms
grand_parent: Class documentation
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
variable including $$u$$, $$v$$, $$w$$, $$\rho$$, $$p$$, but also
Ertel PV, relative vorticity, or custom defined state variables.
 
The WVTransform is an abstract class and as such you must
instatiate one of the concrete subclasses,
 
+ `WVTransformConstantStratification`
+ `WVTransformHydrostatic`
+ `WVTransformSingleMode`
 
                     



## Topics
+ Initialization
  + [`waveVortexTransformFromFile`](/classes/transforms/wvtransform/wavevortextransformfromfile.html) Initialize a WVTransform instance from an existing file
  + [`waveVortexTransformWithDoubleResolution`](/classes/transforms/wvtransform/wavevortextransformwithdoubleresolution.html) create a new WVTransform with double resolution
+ Domain attributes
+ Initial Conditions
  + [`addRandomFlow`](/classes/transforms/wvtransform/addrandomflow.html) add randomized flow to the existing state
  + [`addUVEta`](/classes/transforms/wvtransform/adduveta.html) add $$(u,v,\eta)$$ to the existing values
  + [`initFromNetCDFFile`](/classes/transforms/wvtransform/initfromnetcdffile.html) initialize the flow from a NetCDF file
  + [`initWithRandomFlow`](/classes/transforms/wvtransform/initwithrandomflow.html) initialize with a random flow state
  + [`initWithUVEta`](/classes/transforms/wvtransform/initwithuveta.html) initialize with fluid variables $$(u,v,\eta)$$
  + [`initWithUVRho`](/classes/transforms/wvtransform/initwithuvrho.html) initialize with fluid variables $$(u,v,\rho)$$
  + Waves
    + [`removeAll`](/classes/transforms/wvtransform/removeall.html) removes all energy from the model
+ Energetics
  + [`summarizeEnergyContent`](/classes/transforms/wvtransform/summarizeenergycontent.html) displays a summary of the energy content of the fluid
  + [`summarizeModeEnergy`](/classes/transforms/wvtransform/summarizemodeenergy.html) List the most energetic modes
+ Internal
  + [`WVTransform`](/classes/transforms/wvtransform/wvtransform.html) initialize a WVTransform instance
  + [`addToVariableCache`](/classes/transforms/wvtransform/addtovariablecache.html) add variable to internal cache, in case it is needed again
  + [`clearVariableCacheOfApAmA0DependentVariables`](/classes/transforms/wvtransform/clearvariablecacheofapama0dependentvariables.html) clear the internal cache
  + [`clearVariableCacheOfTimeDependentVariables`](/classes/transforms/wvtransform/clearvariablecacheoftimedependentvariables.html) clear the internal cache of variables that claim to be time dependent
  + [`defaultOperations`](/classes/transforms/wvtransform/defaultoperations.html) return array of WVOperation instances initialized by default
  + [`fetchFromVariableCache`](/classes/transforms/wvtransform/fetchfromvariablecache.html) retrieve a set of variables from the internal cache
  + [`performOperation`](/classes/transforms/wvtransform/performoperation.html) computes (runs) the operation
  + [`performOperationWithName`](/classes/transforms/wvtransform/performoperationwithname.html) computes (runs) the operation
+ Flow components
  + [`addFlowComponent`](/classes/transforms/wvtransform/addflowcomponent.html) add a flow component
  + [`addPrimaryFlowComponent`](/classes/transforms/wvtransform/addprimaryflowcomponent.html) add a primary flow component, automatically added to the flow
  + [`flowComponentWithName`](/classes/transforms/wvtransform/flowcomponentwithname.html) retrieve a WVFlowComponent by name
  + [`primaryFlowComponentWithName`](/classes/transforms/wvtransform/primaryflowcomponentwithname.html) retrieve a WVPrimaryFlowComponent by name
+ Utility function
  + [`spectralVariableWithResolution`](/classes/transforms/wvtransform/spectralvariablewithresolution.html) create a new variable with different resolution
  + Metadata
    + [`addOperation`](/classes/transforms/wvtransform/addoperation.html) add a WVOperation
    + [`flowComponentNames`](/classes/transforms/wvtransform/flowcomponentnames.html) retrieve the names of all available variables
    + [`forcingNames`](/classes/transforms/wvtransform/forcingnames.html) retrieve the names of all available variables. This preserves
    + [`operationWithName`](/classes/transforms/wvtransform/operationwithname.html) retrieve a WVOperation by name
    + [`primaryFlowComponentNames`](/classes/transforms/wvtransform/primaryflowcomponentnames.html) retrieve the names of all available variables
    + [`removeOperation`](/classes/transforms/wvtransform/removeoperation.html) remove an existing WVOperation
+ Write to file
  + [`concatenateVariablesAlongTimeDimension`](/classes/transforms/wvtransform/concatenatevariablesalongtimedimension.html) Concatenate variables along the time dimension
  + [`createNetCDFFileForTimeStepOutput`](/classes/transforms/wvtransform/createnetcdffilefortimestepoutput.html) Output the `WVTransform` to file with variable time dimension
+ Operations
  + Transformations
    + [`convertFromWavenumberToFrequency`](/classes/transforms/wvtransform/convertfromwavenumbertofrequency.html) Summary
    + [`transformUVEtaToWaveVortex`](/classes/transforms/wvtransform/transformuvetatowavevortex.html) transform fluid variables $$(u,v,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
    + [`transformWaveVortexToUVWEta`](/classes/transforms/wvtransform/transformwavevortextouvweta.html) transform wave-vortex coefficients $$(A_+,A_-,A_0)$$ to fluid variables $$(u,v,\eta)$$.
+ Nonlinear flux and energy transfers
  + [`energyFluxFromNonlinearFlux`](/classes/transforms/wvtransform/energyfluxfromnonlinearflux.html) converts nonlinear flux into energy flux
  + [`enstrophyFluxFromNonlinearFlux`](/classes/transforms/wvtransform/enstrophyfluxfromnonlinearflux.html) converts nonlinear flux into enstrophy flux
  + [`nonlinearFluxForFlowComponents`](/classes/transforms/wvtransform/nonlinearfluxforflowcomponents.html) returns the flux of each coefficient as determined by the nonlinear flux operation
  + [`nonlinearFluxWithGradientMasks`](/classes/transforms/wvtransform/nonlinearfluxwithgradientmasks.html) returns the flux of each coefficient as determined by the nonlinear flux operation
  + [`nonlinearFluxWithMask`](/classes/transforms/wvtransform/nonlinearfluxwithmask.html) returns the flux of each coefficient as determined by the nonlinear flux
+ Developer
  + [`propertyAnnotationsForTransform`](/classes/transforms/wvtransform/propertyannotationsfortransform.html) return array of CAPropertyAnnotations for the WVTransform
+ State Variables
  + [`variableAtPositionWithName`](/classes/transforms/wvtransform/variableatpositionwithname.html) Primary method for accessing the dynamical variables on the at any
  + [`variableWithName`](/classes/transforms/wvtransform/variablewithname.html) Primary method for accessing the dynamical variables
+ Other
  + [`A0`](/classes/transforms/wvtransform/a0.html) geostrophic coefficients at reference time t0 (m)
  + [`A0_KE_factor`](/classes/transforms/wvtransform/a0_ke_factor.html) 
  + [`A0_PE_factor`](/classes/transforms/wvtransform/a0_pe_factor.html) 
  + [`A0_Psi_factor`](/classes/transforms/wvtransform/a0_psi_factor.html) 
  + [`A0_QGPV_factor`](/classes/transforms/wvtransform/a0_qgpv_factor.html) 
  + [`A0_TE_factor`](/classes/transforms/wvtransform/a0_te_factor.html) 
  + [`A0_TZ_factor`](/classes/transforms/wvtransform/a0_tz_factor.html) 
  + [`Am`](/classes/transforms/wvtransform/am.html) negative wave coefficients at reference time t0 (m/s)
  + [`Ap`](/classes/transforms/wvtransform/ap.html) positive wave coefficients at reference time t0 (m/s)
  + [`Apm_TE_factor`](/classes/transforms/wvtransform/apm_te_factor.html) 
  + [`addForcing`](/classes/transforms/wvtransform/addforcing.html) 
  + [`addlistener`](/classes/transforms/wvtransform/addlistener.html) 
  + [`classDefinedOperationForKnownVariable`](/classes/transforms/wvtransform/classdefinedoperationforknownvariable.html) This is one of two functions that returns operations for computing
  + [`delete`](/classes/transforms/wvtransform/delete.html) 
  + [`eq`](/classes/transforms/wvtransform/eq.html) 
  + [`findobj`](/classes/transforms/wvtransform/findobj.html) 
  + [`findprop`](/classes/transforms/wvtransform/findprop.html) 
  + [`flowComponentNameMap`](/classes/transforms/wvtransform/flowcomponentnamemap.html) 
  + [`flowComponents`](/classes/transforms/wvtransform/flowcomponents.html) 
  + [`forcing`](/classes/transforms/wvtransform/forcing.html) 
  + [`forcingNameMap`](/classes/transforms/wvtransform/forcingnamemap.html) 
  + [`forcingType`](/classes/transforms/wvtransform/forcingtype.html) 
  + [`forcingWithName`](/classes/transforms/wvtransform/forcingwithname.html) 
  + [`ge`](/classes/transforms/wvtransform/ge.html) 
  + [`gt`](/classes/transforms/wvtransform/gt.html) 
  + [`hasClosure`](/classes/transforms/wvtransform/hasclosure.html) 
  + [`hasForcingWithName`](/classes/transforms/wvtransform/hasforcingwithname.html) 
  + [`hasMeanPressureDifference`](/classes/transforms/wvtransform/hasmeanpressuredifference.html) checks if there is a non-zero mean pressure difference between the top and bottom of the fluid
  + [`hasPVComponent`](/classes/transforms/wvtransform/haspvcomponent.html) 
  + [`hasVariableWithName`](/classes/transforms/wvtransform/hasvariablewithname.html) 
  + [`hasWaveComponent`](/classes/transforms/wvtransform/haswavecomponent.html) 
  + [`initForcingFromNetCDFFile`](/classes/transforms/wvtransform/initforcingfromnetcdffile.html) forcingGroupName = join( [string(class(self)),"forcing"],"-");
  + [`isHydrostatic`](/classes/transforms/wvtransform/ishydrostatic.html) 
  + [`isvalid`](/classes/transforms/wvtransform/isvalid.html) 
  + [`le`](/classes/transforms/wvtransform/le.html) 
  + [`listener`](/classes/transforms/wvtransform/listener.html) 
  + [`lt`](/classes/transforms/wvtransform/lt.html) 
  + [`nFluxedComponents`](/classes/transforms/wvtransform/nfluxedcomponents.html) 
  + [`ne`](/classes/transforms/wvtransform/ne.html) 
  + [`nonlinearFlux`](/classes/transforms/wvtransform/nonlinearflux.html) 
  + [`notify`](/classes/transforms/wvtransform/notify.html) 
  + [`operationForKnownVariable`](/classes/transforms/wvtransform/operationforknownvariable.html) This is one of two functions that returns operations for computing
  + [`operationNameMap`](/classes/transforms/wvtransform/operationnamemap.html) 
  + [`operationVariableNameMap`](/classes/transforms/wvtransform/operationvariablenamemap.html) 
  + [`optimizedTransformsForFlowComponent`](/classes/transforms/wvtransform/optimizedtransformsforflowcomponent.html) returns optimized transforms that avoid unnecessary computation
  + [`primaryFlowComponentNameMap`](/classes/transforms/wvtransform/primaryflowcomponentnamemap.html) 
  + [`primaryFlowComponents`](/classes/transforms/wvtransform/primaryflowcomponents.html) 
  + [`propertyAnnotationForKnownVariable`](/classes/transforms/wvtransform/propertyannotationforknownvariable.html) This is one of two functions that returns operations for computing
  + [`removeAllForcing`](/classes/transforms/wvtransform/removeallforcing.html) 
  + [`removeForcing`](/classes/transforms/wvtransform/removeforcing.html) 
  + [`restoreForcingAmplitudes`](/classes/transforms/wvtransform/restoreforcingamplitudes.html) 
  + [`rk4NonlinearFlux`](/classes/transforms/wvtransform/rk4nonlinearflux.html) 
  + [`rk4NonlinearFluxForFlowComponents`](/classes/transforms/wvtransform/rk4nonlinearfluxforflowcomponents.html) 
  + [`setForcing`](/classes/transforms/wvtransform/setforcing.html) 
  + [`spatialDimensionNames`](/classes/transforms/wvtransform/spatialdimensionnames.html) 
  + [`spatialFluxForcing`](/classes/transforms/wvtransform/spatialfluxforcing.html) 
  + [`spectralAmplitudeForcing`](/classes/transforms/wvtransform/spectralamplitudeforcing.html) 
  + [`spectralDimensionNames`](/classes/transforms/wvtransform/spectraldimensionnames.html) 
  + [`spectralFluxForcing`](/classes/transforms/wvtransform/spectralfluxforcing.html) 
  + [`summarizeDegreesOfFreedom`](/classes/transforms/wvtransform/summarizedegreesoffreedom.html) 
  + [`summarizeFlowComponents`](/classes/transforms/wvtransform/summarizeflowcomponents.html) 
  + [`summarizeForcing`](/classes/transforms/wvtransform/summarizeforcing.html) 
  + [`summarizeVariables`](/classes/transforms/wvtransform/summarizevariables.html) 
  + [`t`](/classes/transforms/wvtransform/t.html) 
  + [`t0`](/classes/transforms/wvtransform/t0.html) 
  + [`timeDependentVariablesNameMap`](/classes/transforms/wvtransform/timedependentvariablesnamemap.html) 
  + [`totalEnergy`](/classes/transforms/wvtransform/totalenergy.html) 
  + [`totalEnergyOfFlowComponent`](/classes/transforms/wvtransform/totalenergyofflowcomponent.html) 
  + [`totalEnergySpatiallyIntegrated`](/classes/transforms/wvtransform/totalenergyspatiallyintegrated.html) 
  + [`totalFlowComponent`](/classes/transforms/wvtransform/totalflowcomponent.html) 
  + [`transformFromSpatialDomainWithFg`](/classes/transforms/wvtransform/transformfromspatialdomainwithfg.html) Required for transformUVEtaToWaveVortex 
  + [`transformFromSpatialDomainWithGg`](/classes/transforms/wvtransform/transformfromspatialdomainwithgg.html) 
  + [`transformToSpatialDomainWithF`](/classes/transforms/wvtransform/transformtospatialdomainwithf.html) Required for transformWaveVortexToUVEta
  + [`transformToSpatialDomainWithFAllDerivatives`](/classes/transforms/wvtransform/transformtospatialdomainwithfallderivatives.html) 
  + [`transformToSpatialDomainWithG`](/classes/transforms/wvtransform/transformtospatialdomainwithg.html) 
  + [`transformToSpatialDomainWithGAllDerivatives`](/classes/transforms/wvtransform/transformtospatialdomainwithgallderivatives.html) 
  + [`updateDependentVariablesNameMap`](/classes/transforms/wvtransform/updatedependentvariablesnamemap.html) 
  + [`variableCache`](/classes/transforms/wvtransform/variablecache.html) 
  + [`variableNames`](/classes/transforms/wvtransform/variablenames.html) 
  + [`version`](/classes/transforms/wvtransform/version.html) 
  + [`waveVortexTransformWithResolution`](/classes/transforms/wvtransform/wavevortextransformwithresolution.html) 
  + [`wvCoefficientDependentVariablesNameMap`](/classes/transforms/wvtransform/wvcoefficientdependentvariablesnamemap.html) 


---