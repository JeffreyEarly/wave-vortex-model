---
layout: default
title: WVTransformStratifiedQG
has_children: false
has_toc: false
mathjax: true
parent: Transforms
grand_parent: Class documentation
nav_order: 6
---

#  WVTransformStratifiedQG

Represent stratified quasigeostrophic flow with variable stratification.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransformStratifiedQG < <a href="/classes/transforms/wvtransform/" title="WVTransform">WVTransform</a></code></pre></div></div>

## Overview

To initialize an instance of the WVTransformStratifiedQG class you
must specify the domain size, the number of grid points, and either
the density profile or the stratification profile.

```matlab
N0 = 3*2*pi/3600;
L_gm = 1300;
N2 = @(z) N0*N0*exp(2*z/L_gm);
wvt = WVTransformStratifiedQG([100e3,100e3,4000],[64,64,65],N2Function=N2,latitude=30);
```

The quasigeostrophic state is stored in
[`A0`](/classes/transforms/wvtransform/a0.html), with current-time view
`A0t`. This transform has no active `Ap`, `Am`, `Apt`, or `Amt` content.




## Topics
+ Create and restore a transform
  + [`WVTransformStratifiedQG`](/classes/transforms/wvtransformstratifiedqg/wvtransformstratifiedqg.html) Create a stratified quasigeostrophic transform.
  + [`waveVortexTransformFromFile`](/classes/transforms/wvtransformstratifiedqg/wavevortextransformfromfile.html) Restore a WVTransformStratifiedQG instance from an existing file
+ Inspect the domain
  + Physical environment
    + Planetary rotation
      + [`beta`](/classes/transforms/wvtransformstratifiedqg/beta.html) Meridional gradient of the Coriolis parameter.
      + [`f`](/classes/transforms/wvtransformstratifiedqg/f.html) Coriolis parameter in radians per second.
      + [`inertialPeriod`](/classes/transforms/wvtransformstratifiedqg/inertialperiod.html) Inertial period in seconds.
      + [`latitude`](/classes/transforms/wvtransformstratifiedqg/latitude.html) Central latitude of the rotating domain in degrees north.
      + [`planetaryRadius`](/classes/transforms/wvtransformstratifiedqg/planetaryradius.html) Radius of the rotating planetary body in meters.
      + [`rotationRate`](/classes/transforms/wvtransformstratifiedqg/rotationrate.html) Planetary rotation rate in radians per second.
    + Stratification and reference density
      + [`N2`](/classes/transforms/wvtransformstratifiedqg/n2.html) Buoyancy frequency squared sampled on the vertical grid.
      + [`N2Function`](/classes/transforms/wvtransformstratifiedqg/n2function.html) Function returning buoyancy frequency squared at requested depths.
      + [`buoyancyPeriod`](/classes/transforms/wvtransformstratifiedqg/buoyancyperiod.html) Shortest buoyancy period in seconds.
      + [`dLnN2`](/classes/transforms/wvtransformstratifiedqg/dlnn2.html) $$\partial_z \ln N^2$$, vertical derivative of the logarithm of squared buoyancy frequency
      + [`rho0`](/classes/transforms/wvtransformstratifiedqg/rho0.html) Boussinesq reference density in kilograms per cubic meter.
      + [`rhoFunction`](/classes/transforms/wvtransformstratifiedqg/rhofunction.html) Function returning the no-motion density profile at requested depths.
    + Gravity
      + [`g`](/classes/transforms/wvtransformstratifiedqg/g.html) Gravitational acceleration in meters per second squared.
  + Spatial grid
    + Coordinate axes
      + [`x`](/classes/transforms/wvtransformstratifiedqg/x.html) Periodic x-coordinate axis in meters.
      + [`y`](/classes/transforms/wvtransformstratifiedqg/y.html) Periodic y-coordinate axis in meters.
      + [`z`](/classes/transforms/wvtransformstratifiedqg/z.html) Three-dimensional vertical-coordinate array in meters.
    + Coordinate arrays
      + [`X`](/classes/transforms/wvtransformstratifiedqg/x_.html) Gridded x-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`Y`](/classes/transforms/wvtransformstratifiedqg/y_.html) Gridded y-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`Z`](/classes/transforms/wvtransformstratifiedqg/z_.html) Gridded vertical-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`xyzGrid`](/classes/transforms/wvtransformstratifiedqg/xyzgrid.html) Return the three-dimensional spatial coordinate arrays.
    + Domain dimensions
      + [`Lx`](/classes/transforms/wvtransformstratifiedqg/lx.html) Periodic domain length in the x direction.
      + [`Ly`](/classes/transforms/wvtransformstratifiedqg/ly.html) Periodic domain length in the y direction.
      + [`Lz`](/classes/transforms/wvtransformstratifiedqg/lz.html) Vertical domain depth in meters.
    + Resolution and shape
      + [`Nx`](/classes/transforms/wvtransformstratifiedqg/nx.html) Number of spatial grid points in the x direction.
      + [`Ny`](/classes/transforms/wvtransformstratifiedqg/ny.html) Number of spatial grid points in the y direction.
      + [`Nz`](/classes/transforms/wvtransformstratifiedqg/nz.html) Number of vertical spatial grid points.
      + [`spatialMatrixSize`](/classes/transforms/wvtransformstratifiedqg/spatialmatrixsize.html) Shape of a gridded physical-space field.
    + Quadrature and integration
      + [`z_int`](/classes/transforms/wvtransformstratifiedqg/z_int.html) Vertical quadrature weights in meters.
  + Spectral grid
    + Compact grid vectors
      + [`k`](/classes/transforms/wvtransformstratifiedqg/k.html) Compact `Nkl`-by-1 x-wavenumber vector in rad/m.
      + [`l`](/classes/transforms/wvtransformstratifiedqg/l.html) Compact `Nkl`-by-1 y-wavenumber vector in rad/m.
      + [`j`](/classes/transforms/wvtransformstratifiedqg/j.html) Dimensionless `Nj`-by-1 vertical-mode index vector.
    + Compact grid arrays
      + [`K`](/classes/transforms/wvtransformstratifiedqg/k_.html) X-direction angular-wavenumber array in rad/m with shape `[Nj Nkl]`.
      + [`L`](/classes/transforms/wvtransformstratifiedqg/l_.html) Y-direction angular-wavenumber array in rad/m with shape `[Nj Nkl]`.
      + [`J`](/classes/transforms/wvtransformstratifiedqg/j_.html) Dimensionless vertical-mode index array with shape `[Nj Nkl]`.
      + [`kljGrid`](/classes/transforms/wvtransformstratifiedqg/kljgrid.html) Return spectral-coordinate arrays in wave-vortex layout.
    + Wavenumber spacing
      + [`dk`](/classes/transforms/wvtransformstratifiedqg/dk.html) Spacing of the x-direction angular-wavenumber axis.
      + [`dl`](/classes/transforms/wvtransformstratifiedqg/dl.html) Spacing of the y-direction angular-wavenumber axis.
    + Horizontal wavenumber geometry
      + [`Kh`](/classes/transforms/wvtransformstratifiedqg/kh.html) Horizontal angular-wavenumber magnitude on the coefficient grid.
      + [`K2`](/classes/transforms/wvtransformstratifiedqg/k2.html) Squared horizontal angular wavenumber on the coefficient grid.
    + Resolution and shape
      + [`Nj`](/classes/transforms/wvtransformstratifiedqg/nj.html) Number of retained vertical modes.
      + [`Nkl`](/classes/transforms/wvtransformstratifiedqg/nkl.html) Number of retained compact horizontal-wavenumber columns.
      + [`spectralMatrixSize`](/classes/transforms/wvtransformstratifiedqg/spectralmatrixsize.html) Shape of a wave-vortex coefficient array.
      + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformstratifiedqg/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
      + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformstratifiedqg/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
      + [`effectiveJMax`](/classes/transforms/wvtransformstratifiedqg/effectivejmax.html) Largest active vertical-mode index.
      + [`summarizeDegreesOfFreedom`](/classes/transforms/wvtransformstratifiedqg/summarizedegreesoffreedom.html) Summarize the spatial grid and active spectral degrees of freedom.
    + Vertical modes and scaling
      + [`verticalModes`](/classes/transforms/wvtransformstratifiedqg/verticalmodes.html) Vertical-mode solution used to construct the transform basis.
      + [`h_0`](/classes/transforms/wvtransformstratifiedqg/h_0.html) Geostrophic equivalent-depth scale for each vertical mode.
      + [`h_pm`](/classes/transforms/wvtransformstratifiedqg/h_pm.html) Wave equivalent depth on the spectral grid.
      + [`Lr2`](/classes/transforms/wvtransformstratifiedqg/lr2.html) Squared Rossby deformation radius in square meters.
      + [`waveModeVerticalStructureAtIndex`](/classes/transforms/wvtransformstratifiedqg/wavemodeverticalstructureatindex.html) Return wave vertical-structure factors at one vertical grid index.
    + Vertical-mode transformation matrices
      + [`FMatrix`](/classes/transforms/wvtransformstratifiedqg/fmatrix.html) Projects F-grid values onto vertical modes with shape `[Nj Nz]`.
      + [`FinvMatrix`](/classes/transforms/wvtransformstratifiedqg/finvmatrix.html) Reconstructs F-grid values from vertical modes with shape `[Nz Nj]`.
      + [`GMatrix`](/classes/transforms/wvtransformstratifiedqg/gmatrix.html) Projects G-grid values onto vertical modes with shape `[Nj Nz]`.
      + [`GinvMatrix`](/classes/transforms/wvtransformstratifiedqg/ginvmatrix.html) Reconstructs G-grid values from vertical modes with shape `[Nz Nj]`.
  + Transform configuration
    + [`isHydrostatic`](/classes/transforms/wvtransformstratifiedqg/ishydrostatic.html) Whether the transform uses the hydrostatic approximation.
    + [`shouldAntialias`](/classes/transforms/wvtransformstratifiedqg/shouldantialias.html) Whether the spectral grid excludes modes that alias quadratic products.
+ Initialize the flow
  + General initialization
    + [`addRandomFlow`](/classes/transforms/wvtransformstratifiedqg/addrandomflow.html) add randomized flow to the existing state
    + [`addUVEta`](/classes/transforms/wvtransformstratifiedqg/adduveta.html) add $$(u,v,\eta)$$ to the existing values
    + [`initFromNetCDFFile`](/classes/transforms/wvtransformstratifiedqg/initfromnetcdffile.html) initialize the flow from a NetCDF file
    + [`initWithRandomFlow`](/classes/transforms/wvtransformstratifiedqg/initwithrandomflow.html) initialize with a random flow state
    + [`initWithUVEta`](/classes/transforms/wvtransformstratifiedqg/initwithuveta.html) initialize with fluid variables $$(u,v,\eta)$$
    + [`initWithUVRho`](/classes/transforms/wvtransformstratifiedqg/initwithuvrho.html) initialize with fluid variables $$(u,v,\rho)$$
    + [`removeAll`](/classes/transforms/wvtransformstratifiedqg/removeall.html) removes all energy from the model
  + Geostrophic motions
    + [`initWithGeostrophicStreamfunction`](/classes/transforms/wvtransformstratifiedqg/initwithgeostrophicstreamfunction.html) initialize with a geostrophic streamfunction
    + [`setGeostrophicStreamfunction`](/classes/transforms/wvtransformstratifiedqg/setgeostrophicstreamfunction.html) set a geostrophic streamfunction
    + [`addGeostrophicStreamfunction`](/classes/transforms/wvtransformstratifiedqg/addgeostrophicstreamfunction.html) add a geostrophic streamfunction to existing geostrophic motions
    + [`setGeostrophicModes`](/classes/transforms/wvtransformstratifiedqg/setgeostrophicmodes.html) set amplitudes of the given geostrophic modes
    + [`addGeostrophicModes`](/classes/transforms/wvtransformstratifiedqg/addgeostrophicmodes.html) add amplitudes of the given geostrophic modes
    + [`removeAllGeostrophicMotions`](/classes/transforms/wvtransformstratifiedqg/removeallgeostrophicmotions.html) remove all geostrophic motions
+ Evaluate physical fields
  + Registered variables
    + [`hasVariableWithName`](/classes/transforms/wvtransformstratifiedqg/hasvariablewithname.html) Test whether state variables are registered by name.
    + [`summarizeVariables`](/classes/transforms/wvtransformstratifiedqg/summarizevariables.html) Print a table of registered state variables and cache status.
    + [`variableNames`](/classes/transforms/wvtransformstratifiedqg/variablenames.html) Return the names of all registered state variables.
    + [`variableWithName`](/classes/transforms/wvtransformstratifiedqg/variablewithname.html) Compute or retrieve one or more registered transform variables.
  + On the model grid
    + Velocity
      + [`u`](/classes/transforms/wvtransformstratifiedqg/u.html) x-component of the fluid velocity
      + [`v`](/classes/transforms/wvtransformstratifiedqg/v.html) y-component of the fluid velocity
    + Density and displacement
      + [`eta`](/classes/transforms/wvtransformstratifiedqg/eta.html) approximate isopycnal deviation
      + [`rho_e`](/classes/transforms/wvtransformstratifiedqg/rho_e.html) excess density
      + [`rho_nm0`](/classes/transforms/wvtransformstratifiedqg/rho_nm0.html) Reference no-motion density profile, `[Nz 1]`, in kg/m³.
      + [`rho_total`](/classes/transforms/wvtransformstratifiedqg/rho_total.html) total potential density
    + Pressure and surface fields
      + [`p`](/classes/transforms/wvtransformstratifiedqg/p.html) pressure anomaly
      + [`pi`](/classes/transforms/wvtransformstratifiedqg/pi.html) height anomaly
      + [`ssh`](/classes/transforms/wvtransformstratifiedqg/ssh.html) sea-surface height
      + [`ssu`](/classes/transforms/wvtransformstratifiedqg/ssu.html) x-component of the fluid velocity at the surface
      + [`ssv`](/classes/transforms/wvtransformstratifiedqg/ssv.html) y-component of the fluid velocity at the surface
    + Vorticity and geostrophic fields
      + [`psi`](/classes/transforms/wvtransformstratifiedqg/psi.html) geostrophic streamfunction
      + [`qgpv`](/classes/transforms/wvtransformstratifiedqg/qgpv.html) quasigeostrophic potential vorticity
      + [`zeta_z`](/classes/transforms/wvtransformstratifiedqg/zeta_z.html) vertical component of relative vorticity
  + At arbitrary positions
    + [`variableAtPositionWithName`](/classes/transforms/wvtransformstratifiedqg/variableatpositionwithname.html) Access dynamical variables at arbitrary positions in the domain.
  + Isopycnal utilities
    + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformstratifiedqg/placeparticlesonisopycnal.html) Return particle depths on the isopycnal identified by a no-motion depth.
+ Manage forcing and closures
  + Configure forcing
    + [`addForcing`](/classes/transforms/wvtransformstratifiedqg/addforcing.html) Add forcing or closure objects to this transform.
    + [`setForcing`](/classes/transforms/wvtransformstratifiedqg/setforcing.html) Replace the complete forcing registry.
    + [`removeForcing`](/classes/transforms/wvtransformstratifiedqg/removeforcing.html) Remove the exact registered forcing objects.
    + [`removeAllForcing`](/classes/transforms/wvtransformstratifiedqg/removeallforcing.html) Remove every forcing and closure from this transform.
  + Inspect forcing and closures
    + [`forcing`](/classes/transforms/wvtransformstratifiedqg/forcing.html) array of WVForcing objects
    + [`forcingNames`](/classes/transforms/wvtransformstratifiedqg/forcingnames.html) Return forcing and closure names in application order.
    + [`forcingWithName`](/classes/transforms/wvtransformstratifiedqg/forcingwithname.html) Return registered forcing objects by name.
    + [`hasForcingWithName`](/classes/transforms/wvtransformstratifiedqg/hasforcingwithname.html) Test whether forcing objects are registered by name.
    + [`hasClosure`](/classes/transforms/wvtransformstratifiedqg/hasclosure.html) Whether a closure is currently attached to the transform.
  + Summarize forcing
    + [`summarizeForcing`](/classes/transforms/wvtransformstratifiedqg/summarizeforcing.html) Print a table of registered forcing and closure objects.
+ Analyze the flow
  + Flow diagnostics
    + [`hasMeanPressureDifference`](/classes/transforms/wvtransformstratifiedqg/hasmeanpressuredifference.html) Diagnose an MDA mean-pressure difference between the boundaries.
    + [`uvMax`](/classes/transforms/wvtransformstratifiedqg/uvmax.html) max horizontal fluid speed
  + Density validity
    + [`isDensityInValidRange`](/classes/transforms/wvtransformstratifiedqg/isdensityinvalidrange.html) Test whether total density remains within the no-motion density range.
  + Potential vorticity and enstrophy
    + [`totalEnstrophy`](/classes/transforms/wvtransformstratifiedqg/totalenstrophy.html) Potential enstrophy computed from geostrophic coefficients.
    + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformstratifiedqg/totalenstrophyspatiallyintegrated.html) Potential enstrophy evaluated from the gridded QGPV field.
  + Spectra
    + Spectral fields
      + [`kAxis`](/classes/transforms/wvtransformstratifiedqg/kaxis.html) Centered `Nx`-by-1 x-wavenumber axis in rad/m.
      + [`lAxis`](/classes/transforms/wvtransformstratifiedqg/laxis.html) Centered `Ny`-by-1 y-wavenumber axis in rad/m.
      + [`transformToKLAxes`](/classes/transforms/wvtransformstratifiedqg/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
      + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformstratifiedqg/crossspectrumwithfgtransform.html) Compute a real modal cross-spectrum using the F-basis transform.
      + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformstratifiedqg/crossspectrumwithggtransform.html) Compute a real modal cross-spectrum using the G-basis transform.
      + [`spectrumWithFgTransform`](/classes/transforms/wvtransformstratifiedqg/spectrumwithfgtransform.html) Compute a modal autospectrum using the F-basis transform.
      + [`spectrumWithGgTransform`](/classes/transforms/wvtransformstratifiedqg/spectrumwithggtransform.html) Compute a modal autospectrum using the G-basis transform.
    + Radial wavenumber
      + [`kRadial`](/classes/transforms/wvtransformstratifiedqg/kradial.html) radial (k,l) wavenumber on the WV grid
      + [`transformToRadialWavenumber`](/classes/transforms/wvtransformstratifiedqg/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
+ Analyze energy
  + Component energy
    + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformstratifiedqg/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
    + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformstratifiedqg/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
    + [`geostrophicEnergy`](/classes/transforms/wvtransformstratifiedqg/geostrophicenergy.html) total energy, geostrophic
    + [`totalEnergyOfFlowComponent`](/classes/transforms/wvtransformstratifiedqg/totalenergyofflowcomponent.html) Compute the energy carried by one flow component.
  + Total energy
    + [`totalEnergy`](/classes/transforms/wvtransformstratifiedqg/totalenergy.html) Total energy computed from wave-vortex coefficients.
    + [`totalEnergySpatiallyIntegrated`](/classes/transforms/wvtransformstratifiedqg/totalenergyspatiallyintegrated.html) Total energy computed from physical-space fields.
  + Energy summaries
    + [`summarizeEnergyContent`](/classes/transforms/wvtransformstratifiedqg/summarizeenergycontent.html) displays a summary of the energy content of the fluid
    + [`summarizeModeEnergy`](/classes/transforms/wvtransformstratifiedqg/summarizemodeenergy.html) List the most energetic modes
+ Save transform state
  + [`writeToFile`](/classes/transforms/wvtransformstratifiedqg/writetofile.html) Write this instance to NetCDF file.
+ Convert representations
  + Physical fields and coefficients
    + [`transformQGPVToWaveVortex`](/classes/transforms/wvtransformstratifiedqg/transformqgpvtowavevortex.html) Project quasigeostrophic potential vorticity onto `A0` coefficients.
    + [`transformUVEtaToWaveVortex`](/classes/transforms/wvtransformstratifiedqg/transformuvetatowavevortex.html) transform fluid variables $$(u,v,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
    + [`transformWaveVortexToUVWEta`](/classes/transforms/wvtransformstratifiedqg/transformwavevortextouvweta.html) transform wave-vortex coefficients $$(A_+,A_-,A_0)$$ to fluid variables $$(u,v,\eta)$$.
+ Differentiate and integrate fields
  + [`diffX`](/classes/transforms/wvtransformstratifiedqg/diffx.html) Differentiate a gridded field in the periodic x direction.
  + [`diffY`](/classes/transforms/wvtransformstratifiedqg/diffy.html) Differentiate a gridded field in the periodic y direction.
  + [`diffZF`](/classes/transforms/wvtransformstratifiedqg/diffzf.html) Differentiate an F-grid field with respect to z.
  + [`diffZG`](/classes/transforms/wvtransformstratifiedqg/diffzg.html) Differentiate a G-grid field with respect to z.
  + [`intZF`](/classes/transforms/wvtransformstratifiedqg/intzf.html) Return the first antiderivative of an F-representation.
  + [`intZG`](/classes/transforms/wvtransformstratifiedqg/intzg.html) Return the bottom-zero first antiderivative of a G-representation.
+ Inspect flow components
  + Primary flow components
    + [`geostrophicComponent`](/classes/transforms/wvtransformstratifiedqg/geostrophiccomponent.html) returns the geostrophic flow component
    + [`primaryFlowComponents`](/classes/transforms/wvtransformstratifiedqg/primaryflowcomponents.html) Primary flow components that partition the active coefficient state.
    + [`primaryFlowComponentNames`](/classes/transforms/wvtransformstratifiedqg/primaryflowcomponentnames.html) retrieve the names of all available variables
    + [`primaryFlowComponentWithName`](/classes/transforms/wvtransformstratifiedqg/primaryflowcomponentwithname.html) retrieve a WVPrimaryFlowComponent by name
  + Registered and combined components
    + [`flowComponents`](/classes/transforms/wvtransformstratifiedqg/flowcomponents.html) All registered physical and diagnostic flow components.
    + [`flowComponentNames`](/classes/transforms/wvtransformstratifiedqg/flowcomponentnames.html) retrieve the names of all available variables
    + [`flowComponentWithName`](/classes/transforms/wvtransformstratifiedqg/flowcomponentwithname.html) retrieve a WVFlowComponent by name
    + [`totalFlowComponent`](/classes/transforms/wvtransformstratifiedqg/totalflowcomponent.html) Combined view of all primary flow components.
  + Summarize flow components
    + [`summarizeFlowComponents`](/classes/transforms/wvtransformstratifiedqg/summarizeflowcomponents.html) Print a table of registered primary and diagnostic components.
+ Inspect wave-vortex coefficients
  + Stored coefficients
    + [`A0`](/classes/transforms/wvtransformstratifiedqg/a0.html) Zero-frequency geostrophic coefficients.
  + Coefficients at the current time
    + [`A0t`](/classes/transforms/wvtransformstratifiedqg/a0t.html) `A0t` is the zero-frequency coefficient array evaluated at the current transform time. On the supported $$f$$-plane transforms, `A0` has no linear phase winding and therefore
  + Coefficient evolution
    + [`t0`](/classes/transforms/wvtransformstratifiedqg/t0.html) Reference time for the stored wave phases, in seconds.
    + [`t`](/classes/transforms/wvtransformstratifiedqg/t.html) Current transform time in seconds.
+ Create a related transform
  + [`hydrostaticTransform`](/classes/transforms/wvtransformstratifiedqg/hydrostatictransform.html) Create the corresponding hydrostatic wave-vortex transform.
  + [`spectralVariableWithResolution`](/classes/transforms/wvtransformstratifiedqg/spectralvariablewithresolution.html) create a new variable with different resolution
  + [`waveVortexTransformWithDoubleResolution`](/classes/transforms/wvtransformstratifiedqg/wavevortextransformwithdoubleresolution.html) create a new WVTransform with double resolution
  + [`waveVortexTransformWithResolution`](/classes/transforms/wvtransformstratifiedqg/wavevortextransformwithresolution.html) Create the same transform family at a new resolution.
+ Extend a transform
  + Flow components
    + [`addFlowComponent`](/classes/transforms/wvtransformstratifiedqg/addflowcomponent.html) add a flow component and its standard variables
    + [`addPrimaryFlowComponent`](/classes/transforms/wvtransformstratifiedqg/addprimaryflowcomponent.html) add a primary flow component, automatically added to the flow
  + Operations and variables
    + [`addOperation`](/classes/transforms/wvtransformstratifiedqg/addoperation.html) Register one or more operations and their output variables.
    + [`operationWithName`](/classes/transforms/wvtransformstratifiedqg/operationwithname.html) retrieve a WVOperation by name
    + [`removeOperation`](/classes/transforms/wvtransformstratifiedqg/removeoperation.html) Remove the exact registered operation and its cached outputs.
+ Get package information
  + [`version`](/classes/transforms/wvtransformstratifiedqg/version.html) Installed WaveVortexModel version.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Projection and reconstruction coefficients
  + [`A0N`](/classes/transforms/wvtransformstratifiedqg/a0n.html) Projects density displacement onto $$A_0$$.
  + [`A0U`](/classes/transforms/wvtransformstratifiedqg/a0u.html) Projects $$u$$ onto $$A_0$$.
  + [`A0V`](/classes/transforms/wvtransformstratifiedqg/a0v.html) Projects $$v$$ onto $$A_0$$.
  + [`A0Z`](/classes/transforms/wvtransformstratifiedqg/a0z.html) Projects vertical vorticity onto $$A_0$$.
  + [`NA0`](/classes/transforms/wvtransformstratifiedqg/na0.html) Reconstructs density displacement from $$A_0$$.
  + [`PA0`](/classes/transforms/wvtransformstratifiedqg/pa0.html) Reconstructs pressure height from $$A_0$$.
  + [`UA0`](/classes/transforms/wvtransformstratifiedqg/ua0.html) Reconstructs $$u$$ from $$A_0$$.
  + [`VA0`](/classes/transforms/wvtransformstratifiedqg/va0.html) Reconstructs $$v$$ from $$A_0$$.
+ Geometry and mode indexing
  + Mode numbers and validity
    + [`isValidConjugateKLModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidconjugateklmodenumber.html) return a boolean indicating whether (k,l) is a valid conjugate WV mode number
    + [`isValidConjugateModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid conjugate mode number
    + [`isValidKLModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidklmodenumber.html) return a boolean indicating whether (k,l) is a valid WV mode number
    + [`isValidModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
    + [`isValidPrimaryKLModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidprimaryklmodenumber.html) return a boolean indicating whether (k,l) is a valid primary (non-conjugate) WV mode number
    + [`isValidPrimaryModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid primary (non-conjugate) mode number
    + [`kMode_dft`](/classes/transforms/wvtransformstratifiedqg/kmode_dft.html) k mode-number on the DFT grid
    + [`kMode_wv`](/classes/transforms/wvtransformstratifiedqg/kmode_wv.html) k mode number on the WV grid
    + [`lMode_dft`](/classes/transforms/wvtransformstratifiedqg/lmode_dft.html) l mode-number on the DFT grid
    + [`lMode_wv`](/classes/transforms/wvtransformstratifiedqg/lmode_wv.html) l mode number on the WV grid
    + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformstratifiedqg/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
  + Linear-index conversion
    + [`indexFromKLModeNumber`](/classes/transforms/wvtransformstratifiedqg/indexfromklmodenumber.html) return the linear index into k_wv and l_wv from a mode number
    + [`indexFromModeNumber`](/classes/transforms/wvtransformstratifiedqg/indexfrommodenumber.html) return the linear index into a spectral matrix given (k,l,j)
    + [`klModeNumberFromIndex`](/classes/transforms/wvtransformstratifiedqg/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
    + [`modeNumberFromIndex`](/classes/transforms/wvtransformstratifiedqg/modenumberfromindex.html) Return mode numbers for spectral linear indices.
  + DFT and WV layout metadata
    + [`Nk_dft`](/classes/transforms/wvtransformstratifiedqg/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
    + [`Nl_dft`](/classes/transforms/wvtransformstratifiedqg/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
    + [`conjugateDimension`](/classes/transforms/wvtransformstratifiedqg/conjugatedimension.html) assumed conjugate dimension
    + [`dftConjugateIndices2D`](/classes/transforms/wvtransformstratifiedqg/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformstratifiedqg/dftprimaryindices2d.html) index into the DFT grid of each WV mode
    + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformstratifiedqg/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
    + [`k_dft`](/classes/transforms/wvtransformstratifiedqg/k_dft.html) k wavenumber dimension on the DFT grid
    + [`kl`](/classes/transforms/wvtransformstratifiedqg/kl.html) wavenumber dimension
    + [`l_dft`](/classes/transforms/wvtransformstratifiedqg/l_dft.html) l wavenumber dimension on the DFT grid
    + [`shouldExcludeConjugates`](/classes/transforms/wvtransformstratifiedqg/shouldexcludeconjugates.html) whether the WV grid excludes redundant Hermitian-conjugate wavenumbers
    + [`shouldExcludeNyquist`](/classes/transforms/wvtransformstratifiedqg/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
  + Layout conversion
    + [`indicesFromDFTGridToWVGrid`](/classes/transforms/wvtransformstratifiedqg/indicesfromdftgridtowvgrid.html) indices to convert from DFT to WV grid
    + [`indicesFromWVGridToDFTGrid`](/classes/transforms/wvtransformstratifiedqg/indicesfromwvgridtodftgrid.html) indices to convert from WV to DFT grid
    + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformstratifiedqg/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
    + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformstratifiedqg/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
    + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformstratifiedqg/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
    + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
    + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
  + Masks and Hermitian bookkeeping
    + [`isHermitian`](/classes/transforms/wvtransformstratifiedqg/ishermitian.html) Check if the matrix is Hermitian. Report errors.
    + [`maskForAliasedModes`](/classes/transforms/wvtransformstratifiedqg/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
    + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformstratifiedqg/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
    + [`maskForNyquistModes`](/classes/transforms/wvtransformstratifiedqg/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
    + [`setConjugateToUnity`](/classes/transforms/wvtransformstratifiedqg/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
+ Spectral transforms and operators
  + [`P0`](/classes/transforms/wvtransformstratifiedqg/p0.html) Preconditioner for F, size(P)=[Nj 1]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`PF0`](/classes/transforms/wvtransformstratifiedqg/pf0.html) size(PF,PG)=[Nj x Nz]
  + [`PF0inv`](/classes/transforms/wvtransformstratifiedqg/pf0inv.html) Transformation matrices
  + [`Q0`](/classes/transforms/wvtransformstratifiedqg/q0.html) Preconditioner for G, size(Q)=[Nj 1]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`QG0`](/classes/transforms/wvtransformstratifiedqg/qg0.html) Preconditioned G-mode forward transformation
  + [`QG0inv`](/classes/transforms/wvtransformstratifiedqg/qg0inv.html) Preconditioned G-mode inverse transformation
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformstratifiedqg/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformstratifiedqg/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`fastTransform`](/classes/transforms/wvtransformstratifiedqg/fasttransform.html) fast transform object
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformstratifiedqg/transformfromspatialdomainwithfio.html)
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformstratifiedqg/transformfromspatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainwithfourieratposition.html)
  + [`transformWithG_wg`](/classes/transforms/wvtransformstratifiedqg/transformwithg_wg.html)
+ Nonlinear flux and forcing internals
  + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformstratifiedqg/enstrophyfluxfromf0.html)
  + [`fluxForForcing`](/classes/transforms/wvtransformstratifiedqg/fluxforforcing.html)
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformstratifiedqg/qgpvfluxfromf0.html)
+ Persistence internals
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformstratifiedqg/classrequiredpropertynames.html)
  + [`geometryFromGroup`](/classes/transforms/wvtransformstratifiedqg/geometryfromgroup.html)
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformstratifiedqg/namesofrequiredpropertiesforgeometry.html)
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformstratifiedqg/namesofrequiredpropertiesforrotatingfplane.html)
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformstratifiedqg/namesofrequiredpropertiesfortransform.html)
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformstratifiedqg/namesoftransformvariables.html)
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformstratifiedqg/newnonrequiredpropertynames.html)
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformstratifiedqg/newrequiredpropertynames.html)
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformstratifiedqg/requiredpropertiesforgeometryfromgroup.html)
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformstratifiedqg/requiredpropertiesforrotatingfplanefromgroup.html)
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformstratifiedqg/requiredpropertiesfortransformfromgroup.html)
  + [`transformFromGroup`](/classes/transforms/wvtransformstratifiedqg/transformfromgroup.html)
+ Caches and registries
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformstratifiedqg/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformstratifiedqg/propertyannotationsforrotatingfplane.html)
+ Class internals
  + [`chebfunForZArray`](/classes/transforms/wvtransformstratifiedqg/chebfunforzarray.html)
  + [`maxFg`](/classes/transforms/wvtransformstratifiedqg/maxfg.html)
  + [`maxFw`](/classes/transforms/wvtransformstratifiedqg/maxfw.html)
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformstratifiedqg/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformstratifiedqg/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformstratifiedqg/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors


---