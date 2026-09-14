---
layout: default
title: WVTransformFreeSurfaceThermalQG
has_children: false
has_toc: false
mathjax: true
parent: Transforms
grand_parent: Class documentation
nav_order: 8
---

#  WVTransformFreeSurfaceThermalQG

Reconstruct complete balanced thermal states with two active boundaries.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransformFreeSurfaceThermalQG < WVTransform</code></pre></div></div>

## Overview

Ath has velocity units and Amda retains the independent real MDA state.
The scientific factory retains every requested polynomial direction.
Supports linear and qualified nonlinear evolution through the exponential integrator.
Register WVNonlinearAdvection with qualified product quadrature, or select
thermalLinearDynamics=true explicitly for a linear configuration.

```matlab
w = WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4*ones(size(z)),thermalModeCount=17,mdaModeCount=4);
fields = w.reconstructFields(["qgpv","endpointAnomalies"]);
```




## Topics
+ Create and restore a transform
  + [`waveVortexTransformFromFile`](/classes/transforms/wvtransformfreesurfacethermalqg/wavevortextransformfromfile.html) Restore thermal scientific state, a committed coefficient record and forcing.
+ Evaluate physical fields
  + Registered variables
    + [`hasVariableWithName`](/classes/transforms/wvtransformfreesurfacethermalqg/hasvariablewithname.html) Test whether state variables are registered by name.
    + [`summarizeVariables`](/classes/transforms/wvtransformfreesurfacethermalqg/summarizevariables.html) Print a table of registered state variables and cache status.
    + [`variableNames`](/classes/transforms/wvtransformfreesurfacethermalqg/variablenames.html) Return the names of all registered state variables.
    + [`variableWithName`](/classes/transforms/wvtransformfreesurfacethermalqg/variablewithname.html) Compute or retrieve one or more registered transform variables.
  + Isopycnal utilities
    + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformfreesurfacethermalqg/placeparticlesonisopycnal.html) Return particle depths on the isopycnal identified by a no-motion depth.
  + On the model grid
    + Density and displacement
      + [`rho_nm0`](/classes/transforms/wvtransformfreesurfacethermalqg/rho_nm0.html) Reference no-motion density profile, `[Nz 1]`, in $$\mathrm{kg\,m^{-3}}$$.
  + At arbitrary positions
    + [`variableAtPositionWithName`](/classes/transforms/wvtransformfreesurfacethermalqg/variableatpositionwithname.html) Access dynamical variables at arbitrary positions in the domain.
+ Inspect wave-vortex coefficients
  + Stored coefficients
    + [`Ap`](/classes/transforms/wvtransformfreesurfacethermalqg/ap.html) Positive-frequency wave–vortex coefficient array.
    + [`Am`](/classes/transforms/wvtransformfreesurfacethermalqg/am.html) Negative-frequency wave–vortex coefficient array.
    + [`A0`](/classes/transforms/wvtransformfreesurfacethermalqg/a0.html) Zero-frequency wave–vortex coefficient array.
    + [`Amda`](/classes/transforms/wvtransformfreesurfacethermalqg/amda.html) Real independent MDA displacement amplitudes in m.
  + Coefficient evolution
    + [`t0`](/classes/transforms/wvtransformfreesurfacethermalqg/t0.html) Reference time for the stored wave phases, in seconds.
    + [`t`](/classes/transforms/wvtransformfreesurfacethermalqg/t.html) Current transform time in seconds.
+ Inspect the domain
  + Spectral grid
    + Vertical-mode transformation matrices
      + [`FMatrix`](/classes/transforms/wvtransformfreesurfacethermalqg/fmatrix.html) Transformation matrix $$F$$ projecting F-grid values onto vertical modes; shape `[Nj Nz]`.
      + [`FinvMatrix`](/classes/transforms/wvtransformfreesurfacethermalqg/finvmatrix.html) Transformation matrix $$F^{-1}$$ reconstructing F-grid values from vertical modes; shape `[Nz Nj]`.
      + [`GMatrix`](/classes/transforms/wvtransformfreesurfacethermalqg/gmatrix.html) Transformation matrix $$G$$ projecting G-grid values onto vertical modes; shape `[Nj Nz]`.
      + [`GinvMatrix`](/classes/transforms/wvtransformfreesurfacethermalqg/ginvmatrix.html) Transformation matrix $$G^{-1}$$ reconstructing G-grid values from vertical modes; shape `[Nz Nj]`.
    + Compact grid arrays
      + [`K`](/classes/transforms/wvtransformfreesurfacethermalqg/k_.html) X-direction angular-wavenumber array in $$\mathrm{rad\,m^{-1}}$$ with shape `[Nj Nkl]`.
      + [`L`](/classes/transforms/wvtransformfreesurfacethermalqg/l_.html) Y-direction angular-wavenumber array in $$\mathrm{rad\,m^{-1}}$$ with shape `[Nj Nkl]`.
      + [`J`](/classes/transforms/wvtransformfreesurfacethermalqg/j_.html) Dimensionless vertical-mode index array with shape `[Nj Nkl]`.
      + [`kljGrid`](/classes/transforms/wvtransformfreesurfacethermalqg/kljgrid.html) Return spectral-coordinate arrays in wave-vortex layout.
    + Horizontal wavenumber geometry
      + [`Kh`](/classes/transforms/wvtransformfreesurfacethermalqg/kh.html) Horizontal angular-wavenumber magnitude on the coefficient grid.
      + [`K2`](/classes/transforms/wvtransformfreesurfacethermalqg/k2.html) Squared horizontal angular wavenumber on the coefficient grid.
    + Vertical modes and scaling
      + [`verticalModes`](/classes/transforms/wvtransformfreesurfacethermalqg/verticalmodes.html) Vertical-mode solution used to construct the transform basis.
      + [`h_0`](/classes/transforms/wvtransformfreesurfacethermalqg/h_0.html) Geostrophic equivalent-depth scale for each vertical mode.
      + [`h_pm`](/classes/transforms/wvtransformfreesurfacethermalqg/h_pm.html) Wave equivalent depth on the spectral grid.
      + [`Lr2`](/classes/transforms/wvtransformfreesurfacethermalqg/lr2.html) Squared Rossby deformation radius in square meters.
      + [`waveModeVerticalStructureAtIndex`](/classes/transforms/wvtransformfreesurfacethermalqg/wavemodeverticalstructureatindex.html) Return wave vertical-structure factors at one vertical grid index.
    + Resolution and shape
      + [`Nj`](/classes/transforms/wvtransformfreesurfacethermalqg/nj.html) Number of retained vertical modes.
      + [`Nkl`](/classes/transforms/wvtransformfreesurfacethermalqg/nkl.html) Number of retained compact horizontal-wavenumber columns.
      + [`spectralMatrixSize`](/classes/transforms/wvtransformfreesurfacethermalqg/spectralmatrixsize.html) Shape of a wave-vortex coefficient array.
      + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformfreesurfacethermalqg/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
      + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformfreesurfacethermalqg/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
      + [`effectiveJMax`](/classes/transforms/wvtransformfreesurfacethermalqg/effectivejmax.html) Largest active vertical-mode index.
      + [`summarizeDegreesOfFreedom`](/classes/transforms/wvtransformfreesurfacethermalqg/summarizedegreesoffreedom.html) Summarize the spatial grid and active spectral degrees of freedom.
    + Wavenumber spacing
      + [`dk`](/classes/transforms/wvtransformfreesurfacethermalqg/dk.html) Spacing of the x-direction angular-wavenumber axis.
      + [`dl`](/classes/transforms/wvtransformfreesurfacethermalqg/dl.html) Spacing of the y-direction angular-wavenumber axis.
    + Compact grid vectors
      + [`k`](/classes/transforms/wvtransformfreesurfacethermalqg/k.html) Compact `Nkl`-by-1 x-wavenumber vector in $$\mathrm{rad\,m^{-1}}$$.
      + [`l`](/classes/transforms/wvtransformfreesurfacethermalqg/l.html) Compact `Nkl`-by-1 y-wavenumber vector in $$\mathrm{rad\,m^{-1}}$$.
      + [`j`](/classes/transforms/wvtransformfreesurfacethermalqg/j.html) Dimensionless `Nj`-by-1 vertical-mode index vector.
  + Spatial grid
    + Domain dimensions
      + [`Lx`](/classes/transforms/wvtransformfreesurfacethermalqg/lx.html) Periodic domain length in the x direction.
      + [`Ly`](/classes/transforms/wvtransformfreesurfacethermalqg/ly.html) Periodic domain length in the y direction.
      + [`Lz`](/classes/transforms/wvtransformfreesurfacethermalqg/lz.html) Vertical domain depth in meters.
    + Resolution and shape
      + [`Nx`](/classes/transforms/wvtransformfreesurfacethermalqg/nx.html) Number of spatial grid points in the x direction.
      + [`Ny`](/classes/transforms/wvtransformfreesurfacethermalqg/ny.html) Number of spatial grid points in the y direction.
      + [`Nz`](/classes/transforms/wvtransformfreesurfacethermalqg/nz.html) Number of vertical spatial grid points.
      + [`spatialMatrixSize`](/classes/transforms/wvtransformfreesurfacethermalqg/spatialmatrixsize.html) Shape of a gridded physical-space field.
    + Coordinate arrays
      + [`X`](/classes/transforms/wvtransformfreesurfacethermalqg/x_.html) Gridded x-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`Y`](/classes/transforms/wvtransformfreesurfacethermalqg/y_.html) Gridded y-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`Z`](/classes/transforms/wvtransformfreesurfacethermalqg/z_.html) Gridded vertical-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`xyzGrid`](/classes/transforms/wvtransformfreesurfacethermalqg/xyzgrid.html) Return the three-dimensional spatial coordinate arrays.
    + Coordinate axes
      + [`x`](/classes/transforms/wvtransformfreesurfacethermalqg/x.html) Periodic x-coordinate axis in meters.
      + [`y`](/classes/transforms/wvtransformfreesurfacethermalqg/y.html) Periodic y-coordinate axis in meters.
      + [`z`](/classes/transforms/wvtransformfreesurfacethermalqg/z.html) Three-dimensional vertical-coordinate array in meters.
    + Quadrature and integration
      + [`z_int`](/classes/transforms/wvtransformfreesurfacethermalqg/z_int.html) Vertical quadrature weights in meters.
  + Physical environment
    + Stratification and reference density
      + [`N2`](/classes/transforms/wvtransformfreesurfacethermalqg/n2.html) Buoyancy frequency squared sampled on the vertical grid.
      + [`N2Function`](/classes/transforms/wvtransformfreesurfacethermalqg/n2function.html) Function returning buoyancy frequency squared at requested depths.
      + [`buoyancyPeriod`](/classes/transforms/wvtransformfreesurfacethermalqg/buoyancyperiod.html) Shortest buoyancy period in seconds.
      + [`dLnN2`](/classes/transforms/wvtransformfreesurfacethermalqg/dlnn2.html) $$\partial_z \ln N^2$$, vertical derivative of the logarithm of squared buoyancy frequency
      + [`rho0`](/classes/transforms/wvtransformfreesurfacethermalqg/rho0.html) Boussinesq reference density in kilograms per cubic meter.
      + [`rhoFunction`](/classes/transforms/wvtransformfreesurfacethermalqg/rhofunction.html) Function returning the no-motion density profile at requested depths.
    + Planetary rotation
      + [`beta`](/classes/transforms/wvtransformfreesurfacethermalqg/beta.html) Meridional gradient of the Coriolis parameter.
      + [`f`](/classes/transforms/wvtransformfreesurfacethermalqg/f.html) Coriolis parameter in radians per second.
      + [`inertialPeriod`](/classes/transforms/wvtransformfreesurfacethermalqg/inertialperiod.html) Inertial period in seconds.
      + [`latitude`](/classes/transforms/wvtransformfreesurfacethermalqg/latitude.html) Central latitude of the rotating domain in degrees north.
      + [`planetaryRadius`](/classes/transforms/wvtransformfreesurfacethermalqg/planetaryradius.html) Radius of the rotating planetary body in meters.
      + [`rotationRate`](/classes/transforms/wvtransformfreesurfacethermalqg/rotationrate.html) Planetary rotation rate in radians per second.
    + Gravity
      + [`g`](/classes/transforms/wvtransformfreesurfacethermalqg/g.html) Gravitational acceleration in meters per second squared.
  + Transform configuration
    + [`isHydrostatic`](/classes/transforms/wvtransformfreesurfacethermalqg/ishydrostatic.html) Whether the transform uses the hydrostatic approximation.
    + [`shouldAntialias`](/classes/transforms/wvtransformfreesurfacethermalqg/shouldantialias.html) Whether the spectral grid excludes modes that alias quadratic products.
+ Extend a transform
  + Flow components
    + [`addFlowComponent`](/classes/transforms/wvtransformfreesurfacethermalqg/addflowcomponent.html) add a flow component and its standard variables
    + [`addPrimaryFlowComponent`](/classes/transforms/wvtransformfreesurfacethermalqg/addprimaryflowcomponent.html) add a primary flow component, automatically added to the flow
  + Operations and variables
    + [`addOperation`](/classes/transforms/wvtransformfreesurfacethermalqg/addoperation.html) Register one or more operations and their output variables.
    + [`operationWithName`](/classes/transforms/wvtransformfreesurfacethermalqg/operationwithname.html) retrieve a WVOperation by name
    + [`removeOperation`](/classes/transforms/wvtransformfreesurfacethermalqg/removeoperation.html) Remove the exact registered operation and its cached outputs.
+ Manage forcing and closures
  + Configure forcing
    + [`addForcing`](/classes/transforms/wvtransformfreesurfacethermalqg/addforcing.html) Add forcing or closure objects to this transform.
    + [`setForcing`](/classes/transforms/wvtransformfreesurfacethermalqg/setforcing.html) Replace the complete forcing registry.
    + [`removeForcing`](/classes/transforms/wvtransformfreesurfacethermalqg/removeforcing.html) Remove the exact registered forcing objects.
    + [`removeAllForcing`](/classes/transforms/wvtransformfreesurfacethermalqg/removeallforcing.html) Remove every forcing and closure from this transform.
  + Inspect forcing and closures
    + [`forcing`](/classes/transforms/wvtransformfreesurfacethermalqg/forcing.html) Registered forcing configuration
    + [`forcingNames`](/classes/transforms/wvtransformfreesurfacethermalqg/forcingnames.html) Return forcing and closure names in application order.
    + [`forcingWithName`](/classes/transforms/wvtransformfreesurfacethermalqg/forcingwithname.html) Return registered forcing objects by name.
    + [`hasForcingWithName`](/classes/transforms/wvtransformfreesurfacethermalqg/hasforcingwithname.html) Test whether forcing objects are registered by name.
    + [`hasClosure`](/classes/transforms/wvtransformfreesurfacethermalqg/hasclosure.html) Whether a closure is currently attached to the transform.
  + Summarize forcing
    + [`summarizeForcing`](/classes/transforms/wvtransformfreesurfacethermalqg/summarizeforcing.html) Print a table of registered forcing and closure objects.
+ Initialize the flow
  + General initialization
    + [`addRandomFlow`](/classes/transforms/wvtransformfreesurfacethermalqg/addrandomflow.html) add randomized flow to the existing state
    + [`addUVEta`](/classes/transforms/wvtransformfreesurfacethermalqg/adduveta.html) add $$(u,v,\eta)$$ to the existing values
    + [`initFromNetCDFFile`](/classes/transforms/wvtransformfreesurfacethermalqg/initfromnetcdffile.html) initialize the flow from a NetCDF file
    + [`initWithRandomFlow`](/classes/transforms/wvtransformfreesurfacethermalqg/initwithrandomflow.html) initialize with a random flow state
    + [`initWithUVEta`](/classes/transforms/wvtransformfreesurfacethermalqg/initwithuveta.html) initialize with fluid variables $$(u,v,\eta)$$
    + [`initWithUVRho`](/classes/transforms/wvtransformfreesurfacethermalqg/initwithuvrho.html) initialize with fluid variables $$(u,v,\rho)$$
    + [`removeAll`](/classes/transforms/wvtransformfreesurfacethermalqg/removeall.html) removes all energy from the model
+ Create a related transform
  + [`coefficientStateForTransform`](/classes/transforms/wvtransformfreesurfacethermalqg/coefficientstatefortransform.html) Fit a compatible thermal target to physical QGPV, endpoints and mean density.
  + [`spectralVariableWithResolution`](/classes/transforms/wvtransformfreesurfacethermalqg/spectralvariablewithresolution.html) create a new variable with different resolution
  + [`waveVortexTransformWithDoubleResolution`](/classes/transforms/wvtransformfreesurfacethermalqg/wavevortextransformwithdoubleresolution.html) create a new WVTransform with double resolution
  + [`waveVortexTransformWithResolution`](/classes/transforms/wvtransformfreesurfacethermalqg/wavevortextransformwithresolution.html) Create the same transform family at a new resolution.
+ Analyze the flow
  + Spectra
    + Frequency
      + [`convertFromWavenumberToFrequency`](/classes/transforms/wvtransformfreesurfacethermalqg/convertfromwavenumbertofrequency.html) Bin wave energy by vertical mode and intrinsic frequency
    + Spectral fields
      + [`kAxis`](/classes/transforms/wvtransformfreesurfacethermalqg/kaxis.html) Centered `Nx`-by-1 x-wavenumber axis in $$\mathrm{rad\,m^{-1}}$$.
      + [`lAxis`](/classes/transforms/wvtransformfreesurfacethermalqg/laxis.html) Centered `Ny`-by-1 y-wavenumber axis in $$\mathrm{rad\,m^{-1}}$$.
      + [`transformToKLAxes`](/classes/transforms/wvtransformfreesurfacethermalqg/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
      + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformfreesurfacethermalqg/crossspectrumwithfgtransform.html) Compute a real modal cross-spectrum using the F-basis transform.
      + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformfreesurfacethermalqg/crossspectrumwithggtransform.html) Compute a real modal cross-spectrum using the G-basis transform.
      + [`spectrumWithFgTransform`](/classes/transforms/wvtransformfreesurfacethermalqg/spectrumwithfgtransform.html) Compute a modal autospectrum using the F-basis transform.
      + [`spectrumWithGgTransform`](/classes/transforms/wvtransformfreesurfacethermalqg/spectrumwithggtransform.html) Compute a modal autospectrum using the G-basis transform.
    + Radial wavenumber
      + [`kRadial`](/classes/transforms/wvtransformfreesurfacethermalqg/kradial.html) radial (k,l) wavenumber on the WV grid
      + [`transformToRadialWavenumber`](/classes/transforms/wvtransformfreesurfacethermalqg/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
  + Flow diagnostics
    + [`hasMeanPressureDifference`](/classes/transforms/wvtransformfreesurfacethermalqg/hasmeanpressuredifference.html) Diagnose an MDA mean-pressure difference between the boundaries.
  + Density validity
    + [`isDensityInValidRange`](/classes/transforms/wvtransformfreesurfacethermalqg/isdensityinvalidrange.html) Test whether total density remains within the no-motion density range.
  + Potential vorticity and enstrophy
    + [`totalPotentialEnstrophy`](/classes/transforms/wvtransformfreesurfacethermalqg/totalpotentialenstrophy.html) Horizontally averaged, depth-integrated full QGPV enstrophy in m s-2.
+ Differentiate and integrate fields
  + [`diffX`](/classes/transforms/wvtransformfreesurfacethermalqg/diffx.html) Differentiate a gridded field in the periodic x direction.
  + [`diffY`](/classes/transforms/wvtransformfreesurfacethermalqg/diffy.html) Differentiate a gridded field in the periodic y direction.
  + [`diffZ`](/classes/transforms/wvtransformfreesurfacethermalqg/diffz.html) Differentiate physical-grid samples once or twice using mapped FFT calculus.
  + [`diffZF`](/classes/transforms/wvtransformfreesurfacethermalqg/diffzf.html) Differentiate an F-grid field with respect to z.
  + [`diffZG`](/classes/transforms/wvtransformfreesurfacethermalqg/diffzg.html) Differentiate a G-grid field with respect to z.
  + [`intZF`](/classes/transforms/wvtransformfreesurfacethermalqg/intzf.html) Return the first antiderivative of an F-representation.
  + [`intZG`](/classes/transforms/wvtransformfreesurfacethermalqg/intzg.html) Return the bottom-zero first antiderivative of a G-representation.
+ Inspect flow components
  + Registered and combined components
    + [`flowComponents`](/classes/transforms/wvtransformfreesurfacethermalqg/flowcomponents.html) All registered physical and diagnostic flow components.
    + [`flowComponentNames`](/classes/transforms/wvtransformfreesurfacethermalqg/flowcomponentnames.html) retrieve the names of all available variables
    + [`flowComponentWithName`](/classes/transforms/wvtransformfreesurfacethermalqg/flowcomponentwithname.html) retrieve a WVFlowComponent by name
    + [`totalFlowComponent`](/classes/transforms/wvtransformfreesurfacethermalqg/totalflowcomponent.html) Combined view of all primary flow components.
  + Primary flow components
    + [`primaryFlowComponents`](/classes/transforms/wvtransformfreesurfacethermalqg/primaryflowcomponents.html) Primary flow components that partition the active coefficient state.
    + [`primaryFlowComponentNames`](/classes/transforms/wvtransformfreesurfacethermalqg/primaryflowcomponentnames.html) retrieve the names of all available variables
    + [`primaryFlowComponentWithName`](/classes/transforms/wvtransformfreesurfacethermalqg/primaryflowcomponentwithname.html) retrieve a WVPrimaryFlowComponent by name
  + Summarize flow components
    + [`summarizeFlowComponents`](/classes/transforms/wvtransformfreesurfacethermalqg/summarizeflowcomponents.html) Print a table of registered primary and diagnostic components.
+ Analyze energy
  + Energy and enstrophy budgets
    + [`quadraticDiagnostics`](/classes/transforms/wvtransformfreesurfacethermalqg/quadraticdiagnostics.html) Evaluate physical inventories and individual or batched directional rates.
  + Energy summaries
    + [`summarizeEnergyContent`](/classes/transforms/wvtransformfreesurfacethermalqg/summarizeenergycontent.html) displays a summary of the energy content of the fluid
    + [`summarizeModeEnergy`](/classes/transforms/wvtransformfreesurfacethermalqg/summarizemodeenergy.html) List the most energetic modes
  + Total energy
    + [`totalEnergy`](/classes/transforms/wvtransformfreesurfacethermalqg/totalenergy.html) Total energy computed from wave-vortex coefficients.
    + [`totalEnergySpatiallyIntegrated`](/classes/transforms/wvtransformfreesurfacethermalqg/totalenergyspatiallyintegrated.html) Total energy computed from physical-space fields.
  + Component energy
    + [`totalEnergyOfFlowComponent`](/classes/transforms/wvtransformfreesurfacethermalqg/totalenergyofflowcomponent.html) Compute the energy carried by one flow component.
+ Convert representations
  + Physical fields and coefficients
    + [`transformUVEtaToWaveVortex`](/classes/transforms/wvtransformfreesurfacethermalqg/transformuvetatowavevortex.html) transform fluid variables $$(u,v,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
    + [`transformWaveVortexToUVWEta`](/classes/transforms/wvtransformfreesurfacethermalqg/transformwavevortextouvweta.html) transform wave-vortex coefficients $$(A_+,A_-,A_0)$$ to fluid variables $$(u,v,\eta)$$.
+ Get package information
  + [`version`](/classes/transforms/wvtransformfreesurfacethermalqg/version.html) Installed WaveVortexModel version.
+ Save transform state
  + [`writeToFile`](/classes/transforms/wvtransformfreesurfacethermalqg/writetofile.html) Write this instance to NetCDF file.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Class internals
  + [`Ath`](/classes/transforms/wvtransformfreesurfacethermalqg/ath.html) Complex complete thermal amplitudes in m/s.
  + [`N20`](/classes/transforms/wvtransformfreesurfacethermalqg/n20.html) Surface squared buoyancy frequency (s-2).
  + [`activeEndpoint`](/classes/transforms/wvtransformfreesurfacethermalqg/activeendpoint.html) Surface then bottom endpoint codes (1).
  + [`assemblyQuadratureCount`](/classes/transforms/wvtransformfreesurfacethermalqg/assemblyquadraturecount.html) Physical-depth assembly quadrature count (1).
  + [`boundaryMomentumTendency`](/classes/transforms/wvtransformfreesurfacethermalqg/boundarymomentumtendency.html) Project boundary momentum stress with the physical-energy weak dual.
  + [`boundaryResolutionTolerance`](/classes/transforms/wvtransformfreesurfacethermalqg/boundaryresolutiontolerance.html) Boundary sampling allowance (1).
  + [`boundaryStreamfunction`](/classes/transforms/wvtransformfreesurfacethermalqg/boundarystreamfunction.html) Reconstruct one endpoint streamfunction without a volume reconstruction.
  + [`chebfunForZArray`](/classes/transforms/wvtransformfreesurfacethermalqg/chebfunforzarray.html)
  + [`conjugateDirection`](/classes/transforms/wvtransformfreesurfacethermalqg/conjugatedirection.html) Conjugate eigenvector permutation (1).
  + [`constructionAssessment`](/classes/transforms/wvtransformfreesurfacethermalqg/constructionassessment.html) Construction evidence; empty after restoration.
  + [`domainSize`](/classes/transforms/wvtransformfreesurfacethermalqg/domainsize.html) Domain lengths (m).
  + [`fromStratification`](/classes/transforms/wvtransformfreesurfacethermalqg/fromstratification.html) Construct a complete thermal basis and independently resolved MDA modes.
  + [`gramTolerance`](/classes/transforms/wvtransformfreesurfacethermalqg/gramtolerance.html) MDA sampling Gram allowance (1).
  + [`inverseScale`](/classes/transforms/wvtransformfreesurfacethermalqg/inversescale.html) Half logarithmic stratification gradient (m-1).
  + [`kappa_z`](/classes/transforms/wvtransformfreesurfacethermalqg/kappa_z.html) Immutable buoyancy diffusivity (m2 s-1).
  + [`khUnique`](/classes/transforms/wvtransformfreesurfacethermalqg/khunique.html) Distinct horizontal radii (m-1).
  + [`klNonzero`](/classes/transforms/wvtransformfreesurfacethermalqg/klnonzero.html) Compact nonzero Fourier indices (1).
  + [`linearEvolutionData`](/classes/transforms/wvtransformfreesurfacethermalqg/linearevolutiondata.html) Build transient eigencoordinates and physical norms from authoritative arrays.
  + [`maxFg`](/classes/transforms/wvtransformfreesurfacethermalqg/maxfg.html)
  + [`maxFw`](/classes/transforms/wvtransformfreesurfacethermalqg/maxfw.html)
  + [`mdaBottomWeight`](/classes/transforms/wvtransformfreesurfacethermalqg/mdabottomweight.html) MDA basis bottom weight (m s-2).
  + [`mdaEnergyGram`](/classes/transforms/wvtransformfreesurfacethermalqg/mdaenergygram.html) Mean physical energy metric (s-2).
  + [`mdaG`](/classes/transforms/wvtransformfreesurfacethermalqg/mdag.html) MDA displacement reconstruction (1).
  + [`mdaGForward`](/classes/transforms/wvtransformfreesurfacethermalqg/mdagforward.html) MDA displacement projector (1).
  + [`mdaGZ`](/classes/transforms/wvtransformfreesurfacethermalqg/mdagz.html) MDA displacement derivative (m-1).
  + [`mdaGeneratorPerDiffusivity`](/classes/transforms/wvtransformfreesurfacethermalqg/mdageneratorperdiffusivity.html) Conservative mean diffusivity operator (m-2).
  + [`mdaSurfaceWeight`](/classes/transforms/wvtransformfreesurfacethermalqg/mdasurfaceweight.html) MDA basis surface weight (m s-2).
  + [`nonlinearCoefficientTendency`](/classes/transforms/wvtransformfreesurfacethermalqg/nonlinearcoefficienttendency.html) Evaluate complete interior and both-endpoint Jacobians on product quadrature.
  + [`nonlinearQuadratureCount`](/classes/transforms/wvtransformfreesurfacethermalqg/nonlinearquadraturecount.html) Nonlinear quadrature policy and construction evidence.
  + [`nonlinearQuadratureResidual`](/classes/transforms/wvtransformfreesurfacethermalqg/nonlinearquadratureresidual.html) Nonlinear quadrature policy and construction evidence.
  + [`nonlinearQuadratureTolerance`](/classes/transforms/wvtransformfreesurfacethermalqg/nonlinearquadraturetolerance.html) Nonlinear quadrature policy and construction evidence.
  + [`nonlinearReferenceResidual`](/classes/transforms/wvtransformfreesurfacethermalqg/nonlinearreferenceresidual.html) Nonlinear quadrature policy and construction evidence.
  + [`physicalDiagnostics`](/classes/transforms/wvtransformfreesurfacethermalqg/physicaldiagnostics.html) Measure physical RMS, native-grid peaks, radial spectra and horizontal tails.
  + [`physicalMetricOperators`](/classes/transforms/wvtransformfreesurfacethermalqg/physicalmetricoperators.html) Build physical quadrature maps and full quadratic metrics from stored arrays.
  + [`polynomialDegree`](/classes/transforms/wvtransformfreesurfacethermalqg/polynomialdegree.html) Complete Legendre polynomial degrees (1).
  + [`polynomialToThermal`](/classes/transforms/wvtransformfreesurfacethermalqg/polynomialtothermal.html) Inverse polynomial map (m-1).
  + [`projectQuasigeostrophicSpatialTendency`](/classes/transforms/wvtransformfreesurfacethermalqg/projectquasigeostrophicspatialtendency.html) Project physical QGPV and strict endpoint-displacement rates with the weak dual.
  + [`projectState`](/classes/transforms/wvtransformfreesurfacethermalqg/projectstate.html) Fit QGPV in physical-depth least squares with exact endpoint constraints.
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformfreesurfacethermalqg/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`quasigeostrophicSpatialState`](/classes/transforms/wvtransformfreesurfacethermalqg/quasigeostrophicspatialstate.html) Return interior and two-endpoint fields in the shared QG spatial convention.
  + [`schemaVersion`](/classes/transforms/wvtransformfreesurfacethermalqg/schemaversion.html) Thermal scientific state schema (1).
  + [`scientificState`](/classes/transforms/wvtransformfreesurfacethermalqg/scientificstate.html) Validated canonical arrays for cheap construction.
  + [`shouldCheckQuadraticAliasing`](/classes/transforms/wvtransformfreesurfacethermalqg/shouldcheckquadraticaliasing.html) Nonlinear quadrature policy and construction evidence.
  + [`sourceDual`](/classes/transforms/wvtransformfreesurfacethermalqg/sourcedual.html) Weak source dual in polynomial trial coordinates (1).
  + [`sourceEndpoint`](/classes/transforms/wvtransformfreesurfacethermalqg/sourceendpoint.html) Strict displacement-source projection (s-1).
  + [`thermalDirection`](/classes/transforms/wvtransformfreesurfacethermalqg/thermaldirection.html) Ordinal complete thermal directions (1).
  + [`thermalEnergyGram`](/classes/transforms/wvtransformfreesurfacethermalqg/thermalenergygram.html) Positive physical energy metric including cross terms (1).
  + [`thermalRatesPerDiffusivity`](/classes/transforms/wvtransformfreesurfacethermalqg/thermalratesperdiffusivity.html) Unit-diffusivity eigenvalues, including null directions (m-2).
  + [`thermalToPolynomial`](/classes/transforms/wvtransformfreesurfacethermalqg/thermaltopolynomial.html) Streamfunction polynomial map for unit velocity amplitudes (m).
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformfreesurfacethermalqg/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformfreesurfacethermalqg/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors
  + [`verticalQuadratureWeights`](/classes/transforms/wvtransformfreesurfacethermalqg/verticalquadratureweights.html) Physical-depth sampling weights (m).
  + [`withDiffusivity`](/classes/transforms/wvtransformfreesurfacethermalqg/withdiffusivity.html) Copy the physical state and fixed basis with new scalar diffusivity.
+ Geometry and mode indexing
  + DFT and WV layout metadata
    + [`Nk_dft`](/classes/transforms/wvtransformfreesurfacethermalqg/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
    + [`Nl_dft`](/classes/transforms/wvtransformfreesurfacethermalqg/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
    + [`conjugateDimension`](/classes/transforms/wvtransformfreesurfacethermalqg/conjugatedimension.html) assumed conjugate dimension
    + [`dftConjugateIndices2D`](/classes/transforms/wvtransformfreesurfacethermalqg/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformfreesurfacethermalqg/dftprimaryindices2d.html) index into the DFT grid of each WV mode
    + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformfreesurfacethermalqg/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
    + [`k_dft`](/classes/transforms/wvtransformfreesurfacethermalqg/k_dft.html) k wavenumber dimension on the DFT grid
    + [`kl`](/classes/transforms/wvtransformfreesurfacethermalqg/kl.html) wavenumber dimension
    + [`l_dft`](/classes/transforms/wvtransformfreesurfacethermalqg/l_dft.html) l wavenumber dimension on the DFT grid
    + [`shouldExcludeConjugates`](/classes/transforms/wvtransformfreesurfacethermalqg/shouldexcludeconjugates.html) whether the WV grid excludes redundant Hermitian-conjugate wavenumbers
    + [`shouldExcludeNyquist`](/classes/transforms/wvtransformfreesurfacethermalqg/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
  + Additional geometry utilities
    + [`domainAxis`](/classes/transforms/wvtransformfreesurfacethermalqg/domainaxis.html) Domain coordinate indices (1).
    + [`gridSize`](/classes/transforms/wvtransformfreesurfacethermalqg/gridsize.html) Physical grid counts (1).
    + [`klNonzeroKhUniqueIndex`](/classes/transforms/wvtransformfreesurfacethermalqg/klnonzerokhuniqueindex.html) Radius page for each column (1).
    + [`mdaMode`](/classes/transforms/wvtransformfreesurfacethermalqg/mdamode.html) Independent MDA directions (1).
    + [`mdaModeCount`](/classes/transforms/wvtransformfreesurfacethermalqg/mdamodecount.html) Number of independent mean directions.
    + [`modeConvergenceTolerance`](/classes/transforms/wvtransformfreesurfacethermalqg/modeconvergencetolerance.html) MDA mode convergence allowance (1).
    + [`thermalModeCount`](/classes/transforms/wvtransformfreesurfacethermalqg/thermalmodecount.html) Number of complete thermal directions.
  + Linear-index conversion
    + [`indexFromKLModeNumber`](/classes/transforms/wvtransformfreesurfacethermalqg/indexfromklmodenumber.html) return the linear index into k_wv and l_wv from a mode number
    + [`indexFromModeNumber`](/classes/transforms/wvtransformfreesurfacethermalqg/indexfrommodenumber.html) return the linear index into a spectral matrix given (k,l,j)
    + [`klModeNumberFromIndex`](/classes/transforms/wvtransformfreesurfacethermalqg/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
    + [`modeNumberFromIndex`](/classes/transforms/wvtransformfreesurfacethermalqg/modenumberfromindex.html) Return mode numbers for spectral linear indices.
  + Layout conversion
    + [`indicesFromDFTGridToWVGrid`](/classes/transforms/wvtransformfreesurfacethermalqg/indicesfromdftgridtowvgrid.html) indices to convert from DFT to WV grid
    + [`indicesFromWVGridToDFTGrid`](/classes/transforms/wvtransformfreesurfacethermalqg/indicesfromwvgridtodftgrid.html) indices to convert from WV to DFT grid
    + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformfreesurfacethermalqg/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
    + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformfreesurfacethermalqg/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
    + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformfreesurfacethermalqg/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
    + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformfreesurfacethermalqg/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
    + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformfreesurfacethermalqg/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
  + Masks and Hermitian bookkeeping
    + [`isHermitian`](/classes/transforms/wvtransformfreesurfacethermalqg/ishermitian.html) Check if the matrix is Hermitian. Report errors.
    + [`maskForAliasedModes`](/classes/transforms/wvtransformfreesurfacethermalqg/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
    + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformfreesurfacethermalqg/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
    + [`maskForNyquistModes`](/classes/transforms/wvtransformfreesurfacethermalqg/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
    + [`setConjugateToUnity`](/classes/transforms/wvtransformfreesurfacethermalqg/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
  + Mode numbers and validity
    + [`isValidConjugateKLModeNumber`](/classes/transforms/wvtransformfreesurfacethermalqg/isvalidconjugateklmodenumber.html) return a boolean indicating whether (k,l) is a valid conjugate WV mode number
    + [`isValidConjugateModeNumber`](/classes/transforms/wvtransformfreesurfacethermalqg/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid conjugate mode number
    + [`isValidKLModeNumber`](/classes/transforms/wvtransformfreesurfacethermalqg/isvalidklmodenumber.html) return a boolean indicating whether (k,l) is a valid WV mode number
    + [`isValidModeNumber`](/classes/transforms/wvtransformfreesurfacethermalqg/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
    + [`isValidPrimaryKLModeNumber`](/classes/transforms/wvtransformfreesurfacethermalqg/isvalidprimaryklmodenumber.html) return a boolean indicating whether (k,l) is a valid primary (non-conjugate) WV mode number
    + [`isValidPrimaryModeNumber`](/classes/transforms/wvtransformfreesurfacethermalqg/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid primary (non-conjugate) mode number
    + [`kMode_dft`](/classes/transforms/wvtransformfreesurfacethermalqg/kmode_dft.html) k mode-number on the DFT grid
    + [`kMode_wv`](/classes/transforms/wvtransformfreesurfacethermalqg/kmode_wv.html) k mode number on the WV grid
    + [`lMode_dft`](/classes/transforms/wvtransformfreesurfacethermalqg/lmode_dft.html) l mode-number on the DFT grid
    + [`lMode_wv`](/classes/transforms/wvtransformfreesurfacethermalqg/lmode_wv.html) l mode number on the WV grid
    + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformfreesurfacethermalqg/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
+ Spectral transforms and operators
  + [`P0`](/classes/transforms/wvtransformfreesurfacethermalqg/p0.html) Preconditioner for F, size(P)=[Nj 1]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`PF0`](/classes/transforms/wvtransformfreesurfacethermalqg/pf0.html) size(PF,PG)=[Nj x Nz]
  + [`PF0inv`](/classes/transforms/wvtransformfreesurfacethermalqg/pf0inv.html) Transformation matrices
  + [`Q0`](/classes/transforms/wvtransformfreesurfacethermalqg/q0.html) Preconditioner for G, size(Q)=[Nj 1]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`QG0`](/classes/transforms/wvtransformfreesurfacethermalqg/qg0.html) dimensionless preconditioned G-mode forward transformation
  + [`QG0inv`](/classes/transforms/wvtransformfreesurfacethermalqg/qg0inv.html) dimensionless preconditioned G-mode inverse transformation
  + [`WVTransformFreeSurfaceThermalQG`](/classes/transforms/wvtransformfreesurfacethermalqg/wvtransformfreesurfacethermalqg.html) Construct from canonical scientific arrays without solving modes.
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformfreesurfacethermalqg/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformfreesurfacethermalqg/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`fastTransform`](/classes/transforms/wvtransformfreesurfacethermalqg/fasttransform.html) fast transform object
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformfreesurfacethermalqg/transformfromspatialdomainwithfio.html)
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformfreesurfacethermalqg/transformfromspatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformfreesurfacethermalqg/transformtospatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformfreesurfacethermalqg/transformtospatialdomainwithfourieratposition.html)
  + [`transformWithG_wg`](/classes/transforms/wvtransformfreesurfacethermalqg/transformwithg_wg.html)
+ Persistence internals
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformfreesurfacethermalqg/classrequiredpropertynames.html) List canonical flat arrays required for restoration.
  + [`geometryFromGroup`](/classes/transforms/wvtransformfreesurfacethermalqg/geometryfromgroup.html)
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformfreesurfacethermalqg/namesofrequiredpropertiesforgeometry.html)
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformfreesurfacethermalqg/namesofrequiredpropertiesforrotatingfplane.html)
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformfreesurfacethermalqg/namesoftransformvariables.html) List the supported physical reconstructions.
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformfreesurfacethermalqg/newnonrequiredpropertynames.html)
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformfreesurfacethermalqg/newrequiredpropertynames.html)
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformfreesurfacethermalqg/requiredpropertiesforgeometryfromgroup.html)
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformfreesurfacethermalqg/requiredpropertiesforrotatingfplanefromgroup.html)
+ Caches and registries
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformfreesurfacethermalqg/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformfreesurfacethermalqg/propertyannotationsforrotatingfplane.html)


---