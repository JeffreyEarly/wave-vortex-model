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

Represent a fluid state with orthogonal wave and geostrophic solutions.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransform < matlab.mixin.indexing.RedefinesDot & CAAnnotatedClass</code></pre></div></div>

## Overview

`WVTransform` is the abstract base class for wave-vortex transforms.
Each concrete transform represents the fluid state at time
`t` with spectral coefficients and exposes physical variables such as
velocity, isopycnal displacement, pressure, and potential vorticity.
Density is denoted by $$\rho$$. Energetic quantities are normalized per
unit reference density $$\rho_0$$ unless a method states otherwise.

The distinguishing feature of a `WVTransform` is that an instantaneous
fluid state is represented as energetically orthogonal wave, inertial,
geostrophic, and mean-density-anomaly constituents. No temporal filter is
required to perform the decomposition. The same object can reconstruct
$$(u,v,w,\rho,p)$$, relative vorticity, potential vorticity, energetic
diagnostics, and custom registered variables from those coefficients.

Choose one of five concrete transform classes:

+ `WVTransformConstantStratification`, in hydrostatic or nonhydrostatic mode
+ `WVTransformHydrostatic`
+ `WVTransformBoussinesq`
+ `WVTransformStratifiedQG`
+ `WVTransformBarotropicQG`

Wave-bearing transforms store positive- and negative-frequency wave and
inertial coefficients in `Ap` and `Am`, and zero-frequency geostrophic
and mean-density-anomaly coefficients in `A0`. Quasigeostrophic
transforms use `A0` only. The `Apt`, `Amt`, and `A0t` variables are the
corresponding coefficients evaluated at the current transform time.





## Topics
+ Create and restore a transform
  + [`spectralVariableWithResolution`](/classes/transforms/wvtransform/spectralvariablewithresolution.html) create a new variable with different resolution
  + [`waveVortexTransformFromFile`](/classes/transforms/wvtransform/wavevortextransformfromfile.html) Initialize a WVTransform instance from an existing file
  + [`waveVortexTransformWithDoubleResolution`](/classes/transforms/wvtransform/wavevortextransformwithdoubleresolution.html) create a new WVTransform with double resolution
  + [`waveVortexTransformWithResolution`](/classes/transforms/wvtransform/wavevortextransformwithresolution.html) Construct the same transform family at a requested resolution.
+ Inspect wave-vortex coefficients
  + Stored coefficients
    + [`A0`](/classes/transforms/wvtransform/a0.html) Zero-frequency geostrophic and mean-density-anomaly coefficients.
    + [`Am`](/classes/transforms/wvtransform/am.html) Negative-frequency wave and inertial coefficients at reference time `t0`.
    + [`Ap`](/classes/transforms/wvtransform/ap.html) Positive-frequency wave and inertial coefficients at reference time `t0`.
+ Set and inspect time
  + [`t`](/classes/transforms/wvtransform/t.html) Current transform time in seconds.
  + [`t0`](/classes/transforms/wvtransform/t0.html) Reference time for the stored wave phases, in seconds.
+ Initialize the flow
  + [`addRandomFlow`](/classes/transforms/wvtransform/addrandomflow.html) add randomized flow to the existing state
  + [`addUVEta`](/classes/transforms/wvtransform/adduveta.html) add $$(u,v,\eta)$$ to the existing values
  + [`initFromNetCDFFile`](/classes/transforms/wvtransform/initfromnetcdffile.html) initialize the flow from a NetCDF file
  + [`initWithRandomFlow`](/classes/transforms/wvtransform/initwithrandomflow.html) initialize with a random flow state
  + [`initWithUVEta`](/classes/transforms/wvtransform/initwithuveta.html) initialize with fluid variables $$(u,v,\eta)$$
  + [`initWithUVRho`](/classes/transforms/wvtransform/initwithuvrho.html) initialize with fluid variables $$(u,v,\rho)$$
  + [`removeAll`](/classes/transforms/wvtransform/removeall.html) removes all energy from the model
+ Evaluate physical fields
  + Registered variables
    + [`hasVariableWithName`](/classes/transforms/wvtransform/hasvariablewithname.html) Test whether state variables are registered by name.
    + [`summarizeVariables`](/classes/transforms/wvtransform/summarizevariables.html) Print a table of registered state variables and cache status.
    + [`variableNames`](/classes/transforms/wvtransform/variablenames.html) Return the names of all registered state variables.
    + [`variableWithName`](/classes/transforms/wvtransform/variablewithname.html) Compute or retrieve one or more registered transform variables.
  + At arbitrary positions
    + [`variableAtPositionWithName`](/classes/transforms/wvtransform/variableatpositionwithname.html) Access dynamical variables at arbitrary positions in the domain.
+ Inspect the domain
  + Rotation and stratification
    + [`isHydrostatic`](/classes/transforms/wvtransform/ishydrostatic.html)
+ Convert representations
  + Physical fields and coefficients
    + [`transformUVEtaToWaveVortex`](/classes/transforms/wvtransform/transformuvetatowavevortex.html) transform fluid variables $$(u,v,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
    + [`transformWaveVortexToUVWEta`](/classes/transforms/wvtransform/transformwavevortextouvweta.html) transform wave-vortex coefficients $$(A_+,A_-,A_0)$$ to fluid variables $$(u,v,\eta)$$.
+ Analyze the flow
  + Energy and summaries
    + [`hasMeanPressureDifference`](/classes/transforms/wvtransform/hasmeanpressuredifference.html) Diagnose an MDA mean-pressure difference between the boundaries.
    + [`summarizeDegreesOfFreedom`](/classes/transforms/wvtransform/summarizedegreesoffreedom.html) Summarize the spatial grid and active spectral degrees of freedom.
    + [`summarizeEnergyContent`](/classes/transforms/wvtransform/summarizeenergycontent.html) displays a summary of the energy content of the fluid
    + [`summarizeModeEnergy`](/classes/transforms/wvtransform/summarizemodeenergy.html) List the most energetic modes
    + [`totalEnergy`](/classes/transforms/wvtransform/totalenergy.html)
    + [`totalEnergyOfFlowComponent`](/classes/transforms/wvtransform/totalenergyofflowcomponent.html)
    + [`totalEnergySpatiallyIntegrated`](/classes/transforms/wvtransform/totalenergyspatiallyintegrated.html)
  + Potential vorticity and enstrophy
    + [`enstrophyFluxFromNonlinearFlux`](/classes/transforms/wvtransform/enstrophyfluxfromnonlinearflux.html) converts nonlinear flux into enstrophy flux
  + Spectra
    + [`convertFromWavenumberToFrequency`](/classes/transforms/wvtransform/convertfromwavenumbertofrequency.html) Bin wave energy by vertical mode and intrinsic frequency
+ Manage forcing and closures
  + [`addForcing`](/classes/transforms/wvtransform/addforcing.html) Add forcing or closure objects to this transform.
  + [`forcing`](/classes/transforms/wvtransform/forcing.html)
  + [`forcingNames`](/classes/transforms/wvtransform/forcingnames.html) retrieve the names of all available variables. This preserves
  + [`forcingWithName`](/classes/transforms/wvtransform/forcingwithname.html) Return registered forcing objects by name.
  + [`hasClosure`](/classes/transforms/wvtransform/hasclosure.html)
  + [`hasForcingWithName`](/classes/transforms/wvtransform/hasforcingwithname.html) Test whether forcing objects are registered by name.
  + [`removeAllForcing`](/classes/transforms/wvtransform/removeallforcing.html) Remove every forcing and closure from this transform.
  + [`removeForcing`](/classes/transforms/wvtransform/removeforcing.html) Remove the exact registered forcing objects.
  + [`setForcing`](/classes/transforms/wvtransform/setforcing.html) Replace the complete forcing registry.
  + [`summarizeForcing`](/classes/transforms/wvtransform/summarizeforcing.html) Print a table of registered forcing and closure objects.
+ Extend a transform
  + Flow components
    + [`addFlowComponent`](/classes/transforms/wvtransform/addflowcomponent.html) add a flow component and its standard variables
    + [`addPrimaryFlowComponent`](/classes/transforms/wvtransform/addprimaryflowcomponent.html) add a primary flow component, automatically added to the flow
    + [`flowComponentNames`](/classes/transforms/wvtransform/flowcomponentnames.html) retrieve the names of all available variables
    + [`flowComponentWithName`](/classes/transforms/wvtransform/flowcomponentwithname.html) retrieve a WVFlowComponent by name
    + [`flowComponents`](/classes/transforms/wvtransform/flowcomponents.html)
    + [`primaryFlowComponentNames`](/classes/transforms/wvtransform/primaryflowcomponentnames.html) retrieve the names of all available variables
    + [`primaryFlowComponentWithName`](/classes/transforms/wvtransform/primaryflowcomponentwithname.html) retrieve a WVPrimaryFlowComponent by name
    + [`primaryFlowComponents`](/classes/transforms/wvtransform/primaryflowcomponents.html)
    + [`summarizeFlowComponents`](/classes/transforms/wvtransform/summarizeflowcomponents.html) Print a table of registered primary and diagnostic components.
    + [`totalFlowComponent`](/classes/transforms/wvtransform/totalflowcomponent.html)
  + Operations and variables
    + [`addOperation`](/classes/transforms/wvtransform/addoperation.html) Register one or more operations and their output variables.
    + [`operationWithName`](/classes/transforms/wvtransform/operationwithname.html) retrieve a WVOperation by name
    + [`removeOperation`](/classes/transforms/wvtransform/removeoperation.html) Remove the exact registered operation and its cached outputs.
+ Get package information
  + [`version`](/classes/transforms/wvtransform/version.html) Installed WaveVortexModel version.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Inspect wave-vortex coefficients
+ Initialize the flow
+ Evaluate physical fields
+ Inspect the domain
+ Convert representations
+ Analyze the flow
+ Extend a transform
+ Projection and reconstruction coefficients
  + [`A0_KE_factor`](/classes/transforms/wvtransform/a0_ke_factor.html)
  + [`A0_PE_factor`](/classes/transforms/wvtransform/a0_pe_factor.html)
  + [`A0_Psi_factor`](/classes/transforms/wvtransform/a0_psi_factor.html)
  + [`A0_QGPV_factor`](/classes/transforms/wvtransform/a0_qgpv_factor.html)
  + [`A0_TE_factor`](/classes/transforms/wvtransform/a0_te_factor.html)
  + [`A0_TZ_factor`](/classes/transforms/wvtransform/a0_tz_factor.html)
  + [`Apm_TE_factor`](/classes/transforms/wvtransform/apm_te_factor.html)
+ Geometry and mode indexing
  + [`concatenateVariablesAlongTimeDimension`](/classes/transforms/wvtransform/concatenatevariablesalongtimedimension.html) Concatenate variables along the time dimension
  + [`spatialDimensionNames`](/classes/transforms/wvtransform/spatialdimensionnames.html)
  + [`spectralDimensionNames`](/classes/transforms/wvtransform/spectraldimensionnames.html)
+ Spectral transforms and operators
  + [`optimizedTransformsForFlowComponent`](/classes/transforms/wvtransform/optimizedtransformsforflowcomponent.html) returns optimized transforms that avoid unnecessary computation
  + [`transformFromSpatialDomainWithFg`](/classes/transforms/wvtransform/transformfromspatialdomainwithfg.html) Required for transformUVEtaToWaveVortex
  + [`transformFromSpatialDomainWithGg`](/classes/transforms/wvtransform/transformfromspatialdomainwithgg.html)
  + [`transformToSpatialDomainWithF`](/classes/transforms/wvtransform/transformtospatialdomainwithf.html) Required for transformWaveVortexToUVEta
  + [`transformToSpatialDomainWithFAllDerivatives`](/classes/transforms/wvtransform/transformtospatialdomainwithfallderivatives.html)
  + [`transformToSpatialDomainWithG`](/classes/transforms/wvtransform/transformtospatialdomainwithg.html)
  + [`transformToSpatialDomainWithGAllDerivatives`](/classes/transforms/wvtransform/transformtospatialdomainwithgallderivatives.html)
+ Nonlinear flux and forcing internals
  + [`energyFluxFromNonlinearFlux`](/classes/transforms/wvtransform/energyfluxfromnonlinearflux.html) converts nonlinear flux into energy flux
  + [`forcingType`](/classes/transforms/wvtransform/forcingtype.html)
  + [`nFluxedComponents`](/classes/transforms/wvtransform/nfluxedcomponents.html)
  + [`nonlinearFlux`](/classes/transforms/wvtransform/nonlinearflux.html)
  + [`nonlinearFluxForFlowComponents`](/classes/transforms/wvtransform/nonlinearfluxforflowcomponents.html) returns the flux of each coefficient as determined by the nonlinear flux operation
  + [`nonlinearFluxWithGradientMasks`](/classes/transforms/wvtransform/nonlinearfluxwithgradientmasks.html) returns the flux of each coefficient as determined by the nonlinear flux operation
  + [`nonlinearFluxWithMask`](/classes/transforms/wvtransform/nonlinearfluxwithmask.html) returns the flux of each coefficient as determined by the nonlinear flux
  + [`rk4NonlinearFlux`](/classes/transforms/wvtransform/rk4nonlinearflux.html)
  + [`rk4NonlinearFluxForFlowComponents`](/classes/transforms/wvtransform/rk4nonlinearfluxforflowcomponents.html)
  + [`spatialFluxForcing`](/classes/transforms/wvtransform/spatialfluxforcing.html)
  + [`spectralAmplitudeForcing`](/classes/transforms/wvtransform/spectralamplitudeforcing.html)
  + [`spectralFluxForcing`](/classes/transforms/wvtransform/spectralfluxforcing.html)
+ Persistence internals
  + [`createNetCDFFileForTimeStepOutput`](/classes/transforms/wvtransform/createnetcdffilefortimestepoutput.html) Output the `WVTransform` to file with variable time dimension
  + [`initForcingFromNetCDFFile`](/classes/transforms/wvtransform/initforcingfromnetcdffile.html) forcingGroupName = join( [string(class(self)),"forcing"],"-");
  + [`restoreForcingAmplitudes`](/classes/transforms/wvtransform/restoreforcingamplitudes.html)
+ Caches and registries
  + [`addToVariableCache`](/classes/transforms/wvtransform/addtovariablecache.html) add variable to internal cache, in case it is needed again
  + [`classDefinedOperationForKnownVariable`](/classes/transforms/wvtransform/classdefinedoperationforknownvariable.html) This is one of two functions that returns operations for computing
  + [`clearVariableCacheOfApAmA0DependentVariables`](/classes/transforms/wvtransform/clearvariablecacheofapama0dependentvariables.html) clear the internal cache
  + [`clearVariableCacheOfTimeDependentVariables`](/classes/transforms/wvtransform/clearvariablecacheoftimedependentvariables.html) clear the internal cache of variables that claim to be time dependent
  + [`defaultOperations`](/classes/transforms/wvtransform/defaultoperations.html) return array of WVOperation instances initialized by default
  + [`fetchFromVariableCache`](/classes/transforms/wvtransform/fetchfromvariablecache.html) retrieve a set of variables from the internal cache
  + [`flowComponentNameMap`](/classes/transforms/wvtransform/flowcomponentnamemap.html)
  + [`forcingNameMap`](/classes/transforms/wvtransform/forcingnamemap.html)
  + [`operationForKnownVariable`](/classes/transforms/wvtransform/operationforknownvariable.html) This is one of two functions that returns operations for computing
  + [`operationNameMap`](/classes/transforms/wvtransform/operationnamemap.html)
  + [`operationVariableNameMap`](/classes/transforms/wvtransform/operationvariablenamemap.html)
  + [`performOperation`](/classes/transforms/wvtransform/performoperation.html) computes (runs) the operation
  + [`performOperationWithName`](/classes/transforms/wvtransform/performoperationwithname.html) computes (runs) the operation
  + [`primaryFlowComponentNameMap`](/classes/transforms/wvtransform/primaryflowcomponentnamemap.html)
  + [`propertyAnnotationForKnownVariable`](/classes/transforms/wvtransform/propertyannotationforknownvariable.html) This is one of two functions that returns operations for computing
  + [`propertyAnnotationsForTransform`](/classes/transforms/wvtransform/propertyannotationsfortransform.html) return array of CAPropertyAnnotations for the WVTransform
  + [`removeFromVariableCache`](/classes/transforms/wvtransform/removefromvariablecache.html) remove one variable from the internal cache
  + [`timeDependentVariablesNameMap`](/classes/transforms/wvtransform/timedependentvariablesnamemap.html)
  + [`updateDependentVariablesNameMap`](/classes/transforms/wvtransform/updatedependentvariablesnamemap.html)
  + [`variableCache`](/classes/transforms/wvtransform/variablecache.html)
  + [`wvCoefficientDependentVariablesNameMap`](/classes/transforms/wvtransform/wvcoefficientdependentvariablesnamemap.html)
+ Class internals
  + [`hasPVComponent`](/classes/transforms/wvtransform/haspvcomponent.html)
  + [`hasWaveComponent`](/classes/transforms/wvtransform/haswavecomponent.html)
+ Construction internals
  + [`WVTransform`](/classes/transforms/wvtransform/wvtransform.html) Initialize the internal WVTransform state for a concrete subclass.


---