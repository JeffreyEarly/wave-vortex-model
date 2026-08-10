---
layout: default
title: WVTransformBarotropicQG
has_children: false
has_toc: false
mathjax: true
parent: Transforms
grand_parent: Class documentation
nav_order: 5
---

#  WVTransformBarotropicQG

Represent two-dimensional equivalent-barotropic quasigeostrophic flow.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransformBarotropicQG < <a href="/classes/transforms/wvtransform/" title="WVTransform">WVTransform</a></code></pre></div></div>

## Overview

This is a two-dimensional, single-layer transform. The `h` parameter
is the equivalent depth; `0.80` m is a representative first-baroclinic
value. The transform stores its state in `A0` and has no wave `Ap` or
`Am` content.

```matlab
Lxy = 50e3;
Nxy = 256;
latitude = 25;
wvt = WVTransformBarotropicQG([Lxy,Lxy],[Nxy,Nxy],h=0.8,latitude=latitude);
```

The quasigeostrophic state is stored in
[`A0`](/classes/transforms/wvtransform/a0.html), with current-time view
`A0t`. This transform has no active `Ap`, `Am`, `Apt`, or `Amt` content.




## Topics
+ Create and restore a transform
  + [`WVTransformBarotropicQG`](/classes/transforms/wvtransformbarotropicqg/wvtransformbarotropicqg.html) Create an equivalent-barotropic quasigeostrophic transform.
  + [`waveVortexTransformFromFile`](/classes/transforms/wvtransformbarotropicqg/wavevortextransformfromfile.html) Restore a WVTransformBarotropicQG instance from an existing file
+ Inspect the domain
  + Physical environment
    + Planetary rotation
      + [`beta`](/classes/transforms/wvtransformbarotropicqg/beta.html) Meridional gradient of the Coriolis parameter.
      + [`f`](/classes/transforms/wvtransformbarotropicqg/f.html) Coriolis parameter in radians per second.
      + [`inertialPeriod`](/classes/transforms/wvtransformbarotropicqg/inertialperiod.html) Inertial period in seconds.
      + [`latitude`](/classes/transforms/wvtransformbarotropicqg/latitude.html) Central latitude of the rotating domain in degrees north.
      + [`planetaryRadius`](/classes/transforms/wvtransformbarotropicqg/planetaryradius.html) Radius of the rotating planetary body in meters.
      + [`rotationRate`](/classes/transforms/wvtransformbarotropicqg/rotationrate.html) Planetary rotation rate in radians per second.
    + Gravity
      + [`g`](/classes/transforms/wvtransformbarotropicqg/g.html) Gravitational acceleration in meters per second squared.
  + Spatial grid
    + Coordinate axes
      + [`x`](/classes/transforms/wvtransformbarotropicqg/x_.html) Periodic x-coordinate axis in meters.
      + [`y`](/classes/transforms/wvtransformbarotropicqg/y_.html) Periodic y-coordinate axis in meters.
    + Coordinate arrays
      + [`X`](/classes/transforms/wvtransformbarotropicqg/x.html) Gridded x-coordinate array in meters with shape `[Nx Ny]`.
      + [`Y`](/classes/transforms/wvtransformbarotropicqg/y.html) Gridded y-coordinate array in meters with shape `[Nx Ny]`.
      + [`xyGrid`](/classes/transforms/wvtransformbarotropicqg/xygrid.html) Return the two-dimensional spatial coordinate arrays.
    + Domain dimensions
      + [`Lx`](/classes/transforms/wvtransformbarotropicqg/lx.html) Periodic domain length in the x direction.
      + [`Ly`](/classes/transforms/wvtransformbarotropicqg/ly.html) Periodic domain length in the y direction.
    + Resolution and shape
      + [`Nx`](/classes/transforms/wvtransformbarotropicqg/nx.html) Number of spatial grid points in the x direction.
      + [`Ny`](/classes/transforms/wvtransformbarotropicqg/ny.html) Number of spatial grid points in the y direction.
      + [`spatialMatrixSize`](/classes/transforms/wvtransformbarotropicqg/spatialmatrixsize.html) Shape of a gridded physical-space field.
  + Spectral grid
    + Axes and spacing
      + [`kAxis`](/classes/transforms/wvtransformbarotropicqg/kaxis.html) Centered x-direction angular-wavenumber axis.
      + [`lAxis`](/classes/transforms/wvtransformbarotropicqg/laxis.html) Centered y-direction angular-wavenumber axis.
      + [`dk`](/classes/transforms/wvtransformbarotropicqg/dk.html) Spacing of the x-direction angular-wavenumber axis.
      + [`dl`](/classes/transforms/wvtransformbarotropicqg/dl.html) Spacing of the y-direction angular-wavenumber axis.
    + Coordinate arrays
      + [`k`](/classes/transforms/wvtransformbarotropicqg/k_.html) Stored x-direction angular wavenumbers on the compact WV grid.
      + [`l`](/classes/transforms/wvtransformbarotropicqg/l_.html) Stored y-direction angular wavenumbers on the compact WV grid.
      + [`K`](/classes/transforms/wvtransformbarotropicqg/k.html) X-direction angular-wavenumber array in rad/m with shape `[1 Nkl]`.
      + [`L`](/classes/transforms/wvtransformbarotropicqg/l.html) Y-direction angular-wavenumber array in rad/m with shape `[1 Nkl]`.
      + [`klGrid`](/classes/transforms/wvtransformbarotropicqg/klgrid.html) Return the barotropic spectral-coordinate arrays.
    + Horizontal wavenumber geometry
      + [`Kh`](/classes/transforms/wvtransformbarotropicqg/kh.html) Horizontal angular-wavenumber magnitude on the coefficient grid.
      + [`K2`](/classes/transforms/wvtransformbarotropicqg/k2.html) Squared horizontal angular wavenumber on the coefficient grid.
    + Resolution and shape
      + [`Nkl`](/classes/transforms/wvtransformbarotropicqg/nkl.html) Number of retained compact horizontal-wavenumber columns.
      + [`spectralMatrixSize`](/classes/transforms/wvtransformbarotropicqg/spectralmatrixsize.html) Shape of a wave-vortex coefficient array.
      + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformbarotropicqg/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
    + Equivalent depth and deformation scale
      + [`h`](/classes/transforms/wvtransformbarotropicqg/h.html) Equivalent depth associated with a vertical mode.
      + [`h_0`](/classes/transforms/wvtransformbarotropicqg/h_0.html) Geostrophic equivalent-depth scale for each vertical mode.
      + [`Lr2`](/classes/transforms/wvtransformbarotropicqg/lr2.html) Squared Rossby deformation radius in square meters.
  + Transform configuration
    + [`isHydrostatic`](/classes/transforms/wvtransformbarotropicqg/ishydrostatic.html) Whether the transform uses the hydrostatic approximation.
    + [`shouldAntialias`](/classes/transforms/wvtransformbarotropicqg/shouldantialias.html) Whether the spectral grid excludes modes that alias quadratic products.
+ Initialize the flow
  + General initialization
    + [`addRandomFlow`](/classes/transforms/wvtransformbarotropicqg/addrandomflow.html) add randomized flow to the existing state
    + [`initFromNetCDFFile`](/classes/transforms/wvtransformbarotropicqg/initfromnetcdffile.html) initialize the flow from a NetCDF file
    + [`initWithRandomFlow`](/classes/transforms/wvtransformbarotropicqg/initwithrandomflow.html) initialize with a random flow state
    + [`removeAll`](/classes/transforms/wvtransformbarotropicqg/removeall.html) removes all energy from the model
  + Geostrophic motions
    + [`initWithGeostrophicStreamfunction`](/classes/transforms/wvtransformbarotropicqg/initwithgeostrophicstreamfunction.html) initialize with a geostrophic streamfunction
    + [`setGeostrophicStreamfunction`](/classes/transforms/wvtransformbarotropicqg/setgeostrophicstreamfunction.html) set a geostrophic streamfunction
    + [`addGeostrophicStreamfunction`](/classes/transforms/wvtransformbarotropicqg/addgeostrophicstreamfunction.html) add a geostrophic streamfunction to existing geostrophic motions
    + [`setGeostrophicModes`](/classes/transforms/wvtransformbarotropicqg/setgeostrophicmodes.html) set amplitudes of the given geostrophic modes
    + [`addGeostrophicModes`](/classes/transforms/wvtransformbarotropicqg/addgeostrophicmodes.html) add amplitudes of the given geostrophic modes
    + [`removeAllGeostrophicMotions`](/classes/transforms/wvtransformbarotropicqg/removeallgeostrophicmotions.html) remove all geostrophic motions
    + [`setSSH`](/classes/transforms/wvtransformbarotropicqg/setssh.html) Set a barotropic geostrophic state from sea-surface height.
+ Evaluate physical fields
  + Registered variables
    + [`hasVariableWithName`](/classes/transforms/wvtransformbarotropicqg/hasvariablewithname.html) Test whether state variables are registered by name.
    + [`summarizeVariables`](/classes/transforms/wvtransformbarotropicqg/summarizevariables.html) Print a table of registered state variables and cache status.
    + [`variableNames`](/classes/transforms/wvtransformbarotropicqg/variablenames.html) Return the names of all registered state variables.
    + [`variableWithName`](/classes/transforms/wvtransformbarotropicqg/variablewithname.html) Compute or retrieve one or more registered transform variables.
  + On the model grid
    + Velocity
      + [`u`](/classes/transforms/wvtransformbarotropicqg/u.html) x-component of the fluid velocity
      + [`v`](/classes/transforms/wvtransformbarotropicqg/v.html) y-component of the fluid velocity
    + Pressure and surface fields
      + [`eta`](/classes/transforms/wvtransformbarotropicqg/eta.html) approximate isopycnal deviation
      + [`pi`](/classes/transforms/wvtransformbarotropicqg/pi.html) height anomaly
      + [`ssh`](/classes/transforms/wvtransformbarotropicqg/ssh.html) sea-surface height
    + Vorticity and geostrophic fields
      + [`psi`](/classes/transforms/wvtransformbarotropicqg/psi.html) geostrophic streamfunction
      + [`qgpv`](/classes/transforms/wvtransformbarotropicqg/qgpv.html) quasigeostrophic potential vorticity
      + [`zeta_z`](/classes/transforms/wvtransformbarotropicqg/zeta_z.html) vertical component of relative vorticity
  + At arbitrary positions
    + [`variableAtPositionWithName`](/classes/transforms/wvtransformbarotropicqg/variableatpositionwithname.html) Access dynamical variables at arbitrary positions in the domain.
+ Manage forcing and closures
  + [`addForcing`](/classes/transforms/wvtransformbarotropicqg/addforcing.html) Add forcing or closure objects to this transform.
  + [`forcing`](/classes/transforms/wvtransformbarotropicqg/forcing.html) array of WVForcing objects
  + [`forcingNames`](/classes/transforms/wvtransformbarotropicqg/forcingnames.html) Return forcing and closure names in application order.
  + [`forcingWithName`](/classes/transforms/wvtransformbarotropicqg/forcingwithname.html) Return registered forcing objects by name.
  + [`hasClosure`](/classes/transforms/wvtransformbarotropicqg/hasclosure.html) Whether a closure is currently attached to the transform.
  + [`hasForcingWithName`](/classes/transforms/wvtransformbarotropicqg/hasforcingwithname.html) Test whether forcing objects are registered by name.
  + [`removeAllForcing`](/classes/transforms/wvtransformbarotropicqg/removeallforcing.html) Remove every forcing and closure from this transform.
  + [`removeForcing`](/classes/transforms/wvtransformbarotropicqg/removeforcing.html) Remove the exact registered forcing objects.
  + [`setForcing`](/classes/transforms/wvtransformbarotropicqg/setforcing.html) Replace the complete forcing registry.
  + [`summarizeForcing`](/classes/transforms/wvtransformbarotropicqg/summarizeforcing.html) Print a table of registered forcing and closure objects.
+ Analyze the flow
  + Energy and summaries
    + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformbarotropicqg/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
    + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformbarotropicqg/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
    + [`geostrophicEnergy`](/classes/transforms/wvtransformbarotropicqg/geostrophicenergy.html) total energy, geostrophic
    + [`hasMeanPressureDifference`](/classes/transforms/wvtransformbarotropicqg/hasmeanpressuredifference.html) Diagnose an MDA mean-pressure difference between the boundaries.
    + [`summarizeDegreesOfFreedom`](/classes/transforms/wvtransformbarotropicqg/summarizedegreesoffreedom.html) Summarize the spatial grid and active spectral degrees of freedom.
    + [`summarizeEnergyContent`](/classes/transforms/wvtransformbarotropicqg/summarizeenergycontent.html) displays a summary of the energy content of the fluid
    + [`summarizeModeEnergy`](/classes/transforms/wvtransformbarotropicqg/summarizemodeenergy.html) List the most energetic modes
    + [`totalEnergy`](/classes/transforms/wvtransformbarotropicqg/totalenergy.html) % - Topic: Energetics
    + [`totalEnergyOfFlowComponent`](/classes/transforms/wvtransformbarotropicqg/totalenergyofflowcomponent.html) Compute the energy carried by one flow component.
    + [`totalEnergySpatiallyIntegrated`](/classes/transforms/wvtransformbarotropicqg/totalenergyspatiallyintegrated.html) % - Topic: Energetics
  + Flow diagnostics
    + [`uvMax`](/classes/transforms/wvtransformbarotropicqg/uvmax.html) max horizontal fluid speed
  + Potential vorticity and enstrophy
    + [`totalEnstrophy`](/classes/transforms/wvtransformbarotropicqg/totalenstrophy.html) Potential enstrophy computed from geostrophic coefficients.
    + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformbarotropicqg/totalenstrophyspatiallyintegrated.html) Potential enstrophy evaluated from the gridded QGPV field.
  + Spectra
    + Spectral fields
      + [`transformToKLAxes`](/classes/transforms/wvtransformbarotropicqg/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
    + Radial wavenumber
      + [`kRadial`](/classes/transforms/wvtransformbarotropicqg/kradial.html) radial (k,l) wavenumber on the WV grid
      + [`transformToRadialWavenumber`](/classes/transforms/wvtransformbarotropicqg/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
+ Save transform state
  + [`writeToFile`](/classes/transforms/wvtransformbarotropicqg/writetofile.html) Write this instance to NetCDF file.
+ Convert representations
  + Physical fields and coefficients
    + [`transformQGPVToWaveVortex`](/classes/transforms/wvtransformbarotropicqg/transformqgpvtowavevortex.html) Project quasigeostrophic potential vorticity onto `A0` coefficients.
+ Differentiate and integrate fields
  + [`diffX`](/classes/transforms/wvtransformbarotropicqg/diffx.html) Differentiate a gridded field in the periodic x direction.
  + [`diffY`](/classes/transforms/wvtransformbarotropicqg/diffy.html) Differentiate a gridded field in the periodic y direction.
+ Inspect flow components
  + [`geostrophicComponent`](/classes/transforms/wvtransformbarotropicqg/geostrophiccomponent.html) returns the geostrophic flow component
  + [`flowComponentNames`](/classes/transforms/wvtransformbarotropicqg/flowcomponentnames.html) retrieve the names of all available variables
  + [`flowComponentWithName`](/classes/transforms/wvtransformbarotropicqg/flowcomponentwithname.html) retrieve a WVFlowComponent by name
  + [`flowComponents`](/classes/transforms/wvtransformbarotropicqg/flowcomponents.html) All registered physical and diagnostic flow components.
  + [`primaryFlowComponentNames`](/classes/transforms/wvtransformbarotropicqg/primaryflowcomponentnames.html) retrieve the names of all available variables
  + [`primaryFlowComponentWithName`](/classes/transforms/wvtransformbarotropicqg/primaryflowcomponentwithname.html) retrieve a WVPrimaryFlowComponent by name
  + [`primaryFlowComponents`](/classes/transforms/wvtransformbarotropicqg/primaryflowcomponents.html) Primary flow components that partition the active coefficient state.
  + [`summarizeFlowComponents`](/classes/transforms/wvtransformbarotropicqg/summarizeflowcomponents.html) Print a table of registered primary and diagnostic components.
  + [`totalFlowComponent`](/classes/transforms/wvtransformbarotropicqg/totalflowcomponent.html) Combined view of all primary flow components.
+ Inspect wave-vortex coefficients
  + Stored coefficients
    + [`A0`](/classes/transforms/wvtransformbarotropicqg/a0.html) Zero-frequency geostrophic coefficients.
  + Coefficients at the current time
    + [`A0t`](/classes/transforms/wvtransformbarotropicqg/a0t.html) `A0t` is the zero-frequency coefficient array evaluated at the current transform time. On the supported $$f$$-plane transforms, `A0` has no linear phase winding and therefore
  + Coefficient evolution
    + [`t0`](/classes/transforms/wvtransformbarotropicqg/t0.html) Reference time for the stored wave phases, in seconds.
    + [`t`](/classes/transforms/wvtransformbarotropicqg/t.html) Current transform time in seconds.
+ Create a related transform
  + [`spectralVariableWithResolution`](/classes/transforms/wvtransformbarotropicqg/spectralvariablewithresolution.html) create a new variable with different resolution
  + [`waveVortexTransformWithDoubleResolution`](/classes/transforms/wvtransformbarotropicqg/wavevortextransformwithdoubleresolution.html) create a new WVTransform with double resolution
  + [`waveVortexTransformWithResolution`](/classes/transforms/wvtransformbarotropicqg/wavevortextransformwithresolution.html) Create the same transform family at a new resolution.
+ Extend a transform
  + Flow components
    + [`addFlowComponent`](/classes/transforms/wvtransformbarotropicqg/addflowcomponent.html) add a flow component and its standard variables
    + [`addPrimaryFlowComponent`](/classes/transforms/wvtransformbarotropicqg/addprimaryflowcomponent.html) add a primary flow component, automatically added to the flow
  + Operations and variables
    + [`addOperation`](/classes/transforms/wvtransformbarotropicqg/addoperation.html) Register one or more operations and their output variables.
    + [`operationWithName`](/classes/transforms/wvtransformbarotropicqg/operationwithname.html) retrieve a WVOperation by name
    + [`removeOperation`](/classes/transforms/wvtransformbarotropicqg/removeoperation.html) Remove the exact registered operation and its cached outputs.
+ Get package information
  + [`version`](/classes/transforms/wvtransformbarotropicqg/version.html) Installed WaveVortexModel version.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Projection and reconstruction coefficients
  + [`A0N`](/classes/transforms/wvtransformbarotropicqg/a0n.html) These projection coefficients map the density-displacement state variable onto $$A_0$$. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 3 entries of $$S^{-1}$$ for the primary internal-gravity-wave and geostrophic solutions in equation C5.
  + [`A0U`](/classes/transforms/wvtransformbarotropicqg/a0u.html) These projection coefficients map the $$u$$ state variable onto $$A_0$$. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 1 entries of $$S^{-1}$$ for the primary internal-gravity-wave and geostrophic solutions in equation C5.
  + [`A0V`](/classes/transforms/wvtransformbarotropicqg/a0v.html) These projection coefficients map the $$v$$ state variable onto $$A_0$$. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 2 entries of $$S^{-1}$$ for the primary internal-gravity-wave and geostrophic solutions in equation C5.
  + [`A0Z`](/classes/transforms/wvtransformbarotropicqg/a0z.html)
  + [`F0`](/classes/transforms/wvtransformbarotropicqg/f0.html)
  + [`Fpv`](/classes/transforms/wvtransformbarotropicqg/fpv.html)
  + [`NA0`](/classes/transforms/wvtransformbarotropicqg/na0.html) These reconstruction coefficients map $$A_0$$ onto the density-displacement state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 3 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`PA0`](/classes/transforms/wvtransformbarotropicqg/pa0.html)
  + [`UA0`](/classes/transforms/wvtransformbarotropicqg/ua0.html) These reconstruction coefficients map $$A_0$$ onto the $$u$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 1, column 3 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`VA0`](/classes/transforms/wvtransformbarotropicqg/va0.html) These reconstruction coefficients map $$A_0$$ onto the $$v$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 2, column 3 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
+ Geometry and mode indexing
  + [`conjugateDimension`](/classes/transforms/wvtransformbarotropicqg/conjugatedimension.html) assumed conjugate dimension
  + [`indexFromKLModeNumber`](/classes/transforms/wvtransformbarotropicqg/indexfromklmodenumber.html) return the linear index into k_wv and l_wv from a mode number
  + [`indexFromModeNumber`](/classes/transforms/wvtransformbarotropicqg/indexfrommodenumber.html)
  + [`indicesFromDFTGridToWVGrid`](/classes/transforms/wvtransformbarotropicqg/indicesfromdftgridtowvgrid.html) indices to convert from DFT to WV grid
  + [`indicesFromWVGridToDFTGrid`](/classes/transforms/wvtransformbarotropicqg/indicesfromwvgridtodftgrid.html) indices to convert from WV to DFT grid
  + [`isValidConjugateKLModeNumber`](/classes/transforms/wvtransformbarotropicqg/isvalidconjugateklmodenumber.html) return a boolean indicating whether (k,l) is a valid conjugate WV mode number
  + [`isValidConjugateModeNumber`](/classes/transforms/wvtransformbarotropicqg/isvalidconjugatemodenumber.html)
  + [`isValidKLModeNumber`](/classes/transforms/wvtransformbarotropicqg/isvalidklmodenumber.html) return a boolean indicating whether (k,l) is a valid WV mode number
  + [`isValidModeNumber`](/classes/transforms/wvtransformbarotropicqg/isvalidmodenumber.html)
  + [`isValidPrimaryKLModeNumber`](/classes/transforms/wvtransformbarotropicqg/isvalidprimaryklmodenumber.html) return a boolean indicating whether (k,l) is a valid primary (non-conjugate) WV mode number
  + [`isValidPrimaryModeNumber`](/classes/transforms/wvtransformbarotropicqg/isvalidprimarymodenumber.html)
  + [`kMode_dft`](/classes/transforms/wvtransformbarotropicqg/kmode_dft.html) k mode-number on the DFT grid
  + [`kMode_wv`](/classes/transforms/wvtransformbarotropicqg/kmode_wv.html) k mode number on the WV grid
  + [`klModeNumberFromIndex`](/classes/transforms/wvtransformbarotropicqg/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
  + [`lMode_dft`](/classes/transforms/wvtransformbarotropicqg/lmode_dft.html) l mode-number on the DFT grid
  + [`lMode_wv`](/classes/transforms/wvtransformbarotropicqg/lmode_wv.html) l mode number on the WV grid
  + [`maskForAliasedModes`](/classes/transforms/wvtransformbarotropicqg/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
  + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformbarotropicqg/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
  + [`maskForNyquistModes`](/classes/transforms/wvtransformbarotropicqg/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
  + [`modeNumberFromIndex`](/classes/transforms/wvtransformbarotropicqg/modenumberfromindex.html)
  + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformbarotropicqg/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
  + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformbarotropicqg/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
  + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformbarotropicqg/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
  + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformbarotropicqg/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
  + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformbarotropicqg/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
  + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformbarotropicqg/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
+ Spectral transforms and operators
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformbarotropicqg/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformbarotropicqg/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`fastTransform`](/classes/transforms/wvtransformbarotropicqg/fasttransform.html) fast transform object
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformbarotropicqg/transformfromspatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformbarotropicqg/transformtospatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformbarotropicqg/transformtospatialdomainwithfourieratposition.html)
+ Nonlinear flux and forcing internals
  + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformbarotropicqg/enstrophyfluxfromf0.html)
  + [`fluxForForcing`](/classes/transforms/wvtransformbarotropicqg/fluxforforcing.html)
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformbarotropicqg/qgpvfluxfromf0.html)
+ Persistence internals
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformbarotropicqg/classrequiredpropertynames.html)
  + [`geometryFromGroup`](/classes/transforms/wvtransformbarotropicqg/geometryfromgroup.html)
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformbarotropicqg/namesofrequiredpropertiesforgeometry.html)
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformbarotropicqg/namesofrequiredpropertiesforrotatingfplane.html)
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformbarotropicqg/namesofrequiredpropertiesfortransform.html)
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformbarotropicqg/namesoftransformvariables.html)
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformbarotropicqg/newnonrequiredpropertynames.html)
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformbarotropicqg/newrequiredpropertynames.html)
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformbarotropicqg/requiredpropertiesforgeometryfromgroup.html) This guy ignores Nz, because we will just use the default
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformbarotropicqg/requiredpropertiesforrotatingfplanefromgroup.html)
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformbarotropicqg/requiredpropertiesfortransformfromgroup.html)
  + [`transformFromGroup`](/classes/transforms/wvtransformbarotropicqg/transformfromgroup.html)
+ Caches and registries
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformbarotropicqg/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformbarotropicqg/propertyannotationsforrotatingfplane.html)
+ Class internals
  + [`Nk_dft`](/classes/transforms/wvtransformbarotropicqg/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
  + [`Nl_dft`](/classes/transforms/wvtransformbarotropicqg/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
  + [`dftConjugateIndices2D`](/classes/transforms/wvtransformbarotropicqg/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
  + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformbarotropicqg/dftprimaryindices2d.html) index into the DFT grid of each WV mode
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformbarotropicqg/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isHermitian`](/classes/transforms/wvtransformbarotropicqg/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`k_dft`](/classes/transforms/wvtransformbarotropicqg/k_dft.html) k wavenumber dimension on the DFT grid
  + [`kl`](/classes/transforms/wvtransformbarotropicqg/kl.html) wavenumber dimension
  + [`l_dft`](/classes/transforms/wvtransformbarotropicqg/l_dft.html) l wavenumber dimension on the DFT grid
  + [`maxFg`](/classes/transforms/wvtransformbarotropicqg/maxfg.html)
  + [`setConjugateToUnity`](/classes/transforms/wvtransformbarotropicqg/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
  + [`shouldExcludeConjugates`](/classes/transforms/wvtransformbarotropicqg/shouldexcludeconjugates.html) whether the WV grid excludes redundant Hermitian-conjugate wavenumbers
  + [`shouldExcludeNyquist`](/classes/transforms/wvtransformbarotropicqg/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers


---