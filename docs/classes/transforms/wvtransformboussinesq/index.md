---
layout: default
title: WVTransformBoussinesq
has_children: false
has_toc: false
mathjax: true
parent: Transforms
grand_parent: Class documentation
nav_order: 2
---

#  WVTransformBoussinesq

Decompose nonhydrostatic variable-stratification flow into wave and geostrophic components.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransformBoussinesq < <a href="/classes/transforms/wvtransform/" title="WVTransform">WVTransform</a></code></pre></div></div>

## Overview

To initialize an instance of the WVTransformBoussinesq class you
must specify the domain size, the number of grid points, and either
the density profile or the stratification profile.

```matlab
N0 = 3*2*pi/3600;
L_gm = 1300;
N2 = @(z) N0*N0*exp(2*z/L_gm);
wvt = WVTransformBoussinesq([100e3,100e3,4000],[64,64,65],N2Function=N2,latitude=30);
```

The transform state is stored in [`Ap`](/classes/transforms/wvtransform/ap.html),
[`Am`](/classes/transforms/wvtransform/am.html), and
[`A0`](/classes/transforms/wvtransform/a0.html). Their current-time
views are `Apt`, `Amt`, and `A0t`.




## Topics
+ Create and restore a transform
  + [`WVTransformBoussinesq`](/classes/transforms/wvtransformboussinesq/wvtransformboussinesq.html) Create a nonhydrostatic wave-vortex transform for variable stratification.
  + [`waveVortexTransformFromFile`](/classes/transforms/wvtransformboussinesq/wavevortextransformfromfile.html) Restore a WVTransformBoussinesq instance from an existing file
+ Inspect the domain
  + Physical environment
    + Planetary rotation
      + [`beta`](/classes/transforms/wvtransformboussinesq/beta.html) Meridional gradient of the Coriolis parameter.
      + [`f`](/classes/transforms/wvtransformboussinesq/f.html) Coriolis parameter in radians per second.
      + [`inertialPeriod`](/classes/transforms/wvtransformboussinesq/inertialperiod.html) Inertial period in seconds.
      + [`latitude`](/classes/transforms/wvtransformboussinesq/latitude.html) Central latitude of the rotating domain in degrees north.
      + [`planetaryRadius`](/classes/transforms/wvtransformboussinesq/planetaryradius.html) Radius of the rotating planetary body in meters.
      + [`rotationRate`](/classes/transforms/wvtransformboussinesq/rotationrate.html) Planetary rotation rate in radians per second.
    + Stratification and reference density
      + [`N2`](/classes/transforms/wvtransformboussinesq/n2.html) Buoyancy frequency squared sampled on the vertical grid.
      + [`N2Function`](/classes/transforms/wvtransformboussinesq/n2function.html) Function returning buoyancy frequency squared at requested depths.
      + [`buoyancyPeriod`](/classes/transforms/wvtransformboussinesq/buoyancyperiod.html) Shortest buoyancy period in seconds.
      + [`dLnN2`](/classes/transforms/wvtransformboussinesq/dlnn2.html) $$\partial_z \ln N^2$$, vertical derivative of the logarithm of squared buoyancy frequency
      + [`rho0`](/classes/transforms/wvtransformboussinesq/rho0.html) Boussinesq reference density in kilograms per cubic meter.
      + [`rhoFunction`](/classes/transforms/wvtransformboussinesq/rhofunction.html) Function returning the no-motion density profile at requested depths.
      + [`shouldUseTrueNoMotionProfile`](/classes/transforms/wvtransformboussinesq/shouldusetruenomotionprofile.html) Whether density diagnostics use the supplied no-motion profile directly.
    + Gravity
      + [`g`](/classes/transforms/wvtransformboussinesq/g.html) Gravitational acceleration in meters per second squared.
  + Spatial grid
    + Coordinate axes
      + [`x`](/classes/transforms/wvtransformboussinesq/x.html) Periodic x-coordinate axis in meters.
      + [`y`](/classes/transforms/wvtransformboussinesq/y.html) Periodic y-coordinate axis in meters.
      + [`z`](/classes/transforms/wvtransformboussinesq/z.html) Three-dimensional vertical-coordinate array in meters.
    + Coordinate arrays
      + [`X`](/classes/transforms/wvtransformboussinesq/x_.html) Gridded x-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`Y`](/classes/transforms/wvtransformboussinesq/y_.html) Gridded y-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`Z`](/classes/transforms/wvtransformboussinesq/z_.html) Gridded vertical-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`xyzGrid`](/classes/transforms/wvtransformboussinesq/xyzgrid.html) Return the three-dimensional spatial coordinate arrays.
    + Domain dimensions
      + [`Lx`](/classes/transforms/wvtransformboussinesq/lx.html) Periodic domain length in the x direction.
      + [`Ly`](/classes/transforms/wvtransformboussinesq/ly.html) Periodic domain length in the y direction.
      + [`Lz`](/classes/transforms/wvtransformboussinesq/lz.html) Vertical domain depth in meters.
    + Resolution and shape
      + [`Nx`](/classes/transforms/wvtransformboussinesq/nx.html) Number of spatial grid points in the x direction.
      + [`Ny`](/classes/transforms/wvtransformboussinesq/ny.html) Number of spatial grid points in the y direction.
      + [`Nz`](/classes/transforms/wvtransformboussinesq/nz.html) Number of vertical spatial grid points.
      + [`spatialMatrixSize`](/classes/transforms/wvtransformboussinesq/spatialmatrixsize.html) Shape of a gridded physical-space field.
    + Quadrature and integration
      + [`z_int`](/classes/transforms/wvtransformboussinesq/z_int.html) Vertical quadrature weights in meters.
      + [`volumeIntegral`](/classes/transforms/wvtransformboussinesq/volumeintegral.html) Compute the horizontally averaged depth integral of a scalar field.
  + Spectral grid
    + Axes and spacing
      + [`kAxis`](/classes/transforms/wvtransformboussinesq/kaxis.html) Centered x-direction angular-wavenumber axis.
      + [`lAxis`](/classes/transforms/wvtransformboussinesq/laxis.html) Centered y-direction angular-wavenumber axis.
      + [`j`](/classes/transforms/wvtransformboussinesq/j.html) Vertical-mode index axis.
      + [`dk`](/classes/transforms/wvtransformboussinesq/dk.html) Spacing of the x-direction angular-wavenumber axis.
      + [`dl`](/classes/transforms/wvtransformboussinesq/dl.html) Spacing of the y-direction angular-wavenumber axis.
    + Coordinate arrays
      + [`k`](/classes/transforms/wvtransformboussinesq/k.html) Stored x-direction angular wavenumbers on the compact WV grid.
      + [`l`](/classes/transforms/wvtransformboussinesq/l.html) Stored y-direction angular wavenumbers on the compact WV grid.
      + [`K`](/classes/transforms/wvtransformboussinesq/k_.html) X-direction angular-wavenumber array in rad/m with shape `[Nj Nkl]`.
      + [`L`](/classes/transforms/wvtransformboussinesq/l_.html) Y-direction angular-wavenumber array in rad/m with shape `[Nj Nkl]`.
      + [`J`](/classes/transforms/wvtransformboussinesq/j_.html) Dimensionless vertical-mode index array with shape `[Nj Nkl]`.
      + [`kljGrid`](/classes/transforms/wvtransformboussinesq/kljgrid.html) Return spectral-coordinate arrays in wave-vortex layout.
    + Horizontal wavenumber geometry
      + [`Kh`](/classes/transforms/wvtransformboussinesq/kh.html) Horizontal angular-wavenumber magnitude on the coefficient grid.
      + [`K2`](/classes/transforms/wvtransformboussinesq/k2.html) Squared horizontal angular wavenumber on the coefficient grid.
    + Resolution and shape
      + [`Nj`](/classes/transforms/wvtransformboussinesq/nj.html) Number of retained vertical modes.
      + [`Nkl`](/classes/transforms/wvtransformboussinesq/nkl.html) Number of retained compact horizontal-wavenumber columns.
      + [`spectralMatrixSize`](/classes/transforms/wvtransformboussinesq/spectralmatrixsize.html) Shape of a wave-vortex coefficient array.
      + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformboussinesq/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
      + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformboussinesq/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
      + [`effectiveJMax`](/classes/transforms/wvtransformboussinesq/effectivejmax.html) Largest active vertical-mode index.
    + Vertical modes and scaling
      + [`verticalModes`](/classes/transforms/wvtransformboussinesq/verticalmodes.html) Vertical-mode solution used to construct the transform basis.
      + [`h_0`](/classes/transforms/wvtransformboussinesq/h_0.html) Geostrophic equivalent-depth scale for each vertical mode.
      + [`h_pm`](/classes/transforms/wvtransformboussinesq/h_pm.html) Wave equivalent depth on the spectral grid.
      + [`Lr2`](/classes/transforms/wvtransformboussinesq/lr2.html) Squared Rossby deformation radius in square meters.
      + [`waveModeVerticalStructureAtIndex`](/classes/transforms/wvtransformboussinesq/wavemodeverticalstructureatindex.html) Return wave vertical-structure factors at one vertical grid index.
  + Transform configuration
    + [`isHydrostatic`](/classes/transforms/wvtransformboussinesq/ishydrostatic.html) Whether the transform uses the hydrostatic approximation.
    + [`shouldAntialias`](/classes/transforms/wvtransformboussinesq/shouldantialias.html) Whether the spectral grid excludes modes that alias quadratic products.
+ Initialize the flow
  + General initialization
    + [`addRandomFlow`](/classes/transforms/wvtransformboussinesq/addrandomflow.html) add randomized flow to the existing state
    + [`addUVEta`](/classes/transforms/wvtransformboussinesq/adduveta.html) add $$(u,v,\eta)$$ to the existing values
    + [`initFromNetCDFFile`](/classes/transforms/wvtransformboussinesq/initfromnetcdffile.html) initialize the flow from a NetCDF file
    + [`initWithRandomFlow`](/classes/transforms/wvtransformboussinesq/initwithrandomflow.html) initialize with a random flow state
    + [`initWithUVEta`](/classes/transforms/wvtransformboussinesq/initwithuveta.html) initialize with fluid variables $$(u,v,\eta)$$
    + [`initWithUVRho`](/classes/transforms/wvtransformboussinesq/initwithuvrho.html) initialize with fluid variables $$(u,v,\rho)$$
    + [`removeAll`](/classes/transforms/wvtransformboussinesq/removeall.html) removes all energy from the model
  + Waves
    + Individual modes
      + [`addWaveModes`](/classes/transforms/wvtransformboussinesq/addwavemodes.html) add amplitudes of the given wave modes
      + [`initWithWaveModes`](/classes/transforms/wvtransformboussinesq/initwithwavemodes.html) initialize with the given wave modes
      + [`removeAllWaves`](/classes/transforms/wvtransformboussinesq/removeallwaves.html) removes all wave from the model, including inertial oscillations
      + [`setWaveModes`](/classes/transforms/wvtransformboussinesq/setwavemodes.html) set amplitudes of the given wave modes
    + Wave spectra
      + [`addGMSpectrum`](/classes/transforms/wvtransformboussinesq/addgmspectrum.html) add waves following a Garrett-Munk spectrum
      + [`addWavesWithFrequencySpectrum`](/classes/transforms/wvtransformboussinesq/addwaveswithfrequencyspectrum.html) add waves with a specified frequency spectrum
      + [`initWavesWithFrequencySpectrum`](/classes/transforms/wvtransformboussinesq/initwaveswithfrequencyspectrum.html) initialize with waves of a specified frequency spectrum
      + [`initWithAlternativeSpectrum`](/classes/transforms/wvtransformboussinesq/initwithalternativespectrum.html) initialize with an alternative formulation of the GM spectrum in the wavenumber domain.
      + [`initWithGMSpectrum`](/classes/transforms/wvtransformboussinesq/initwithgmspectrum.html) initialize the wave field following a Garrett-Munk spectrum
  + Inertial oscillations
    + [`addInertialMotions`](/classes/transforms/wvtransformboussinesq/addinertialmotions.html) add inertial motions to existing inertial motions
    + [`initWithInertialMotions`](/classes/transforms/wvtransformboussinesq/initwithinertialmotions.html) initialize with inertial motions
    + [`removeAllInertialMotions`](/classes/transforms/wvtransformboussinesq/removeallinertialmotions.html) remove all inertial motions
    + [`setInertialMotions`](/classes/transforms/wvtransformboussinesq/setinertialmotions.html) set inertial motions
  + Geostrophic motions
    + [`initWithGeostrophicStreamfunction`](/classes/transforms/wvtransformboussinesq/initwithgeostrophicstreamfunction.html) initialize with a geostrophic streamfunction
    + [`setGeostrophicStreamfunction`](/classes/transforms/wvtransformboussinesq/setgeostrophicstreamfunction.html) set a geostrophic streamfunction
    + [`addGeostrophicStreamfunction`](/classes/transforms/wvtransformboussinesq/addgeostrophicstreamfunction.html) add a geostrophic streamfunction to existing geostrophic motions
    + [`setGeostrophicModes`](/classes/transforms/wvtransformboussinesq/setgeostrophicmodes.html) set amplitudes of the given geostrophic modes
    + [`addGeostrophicModes`](/classes/transforms/wvtransformboussinesq/addgeostrophicmodes.html) add amplitudes of the given geostrophic modes
    + [`removeAllGeostrophicMotions`](/classes/transforms/wvtransformboussinesq/removeallgeostrophicmotions.html) remove all geostrophic motions
  + Mean density anomalies
    + [`addMeanDensityAnomaly`](/classes/transforms/wvtransformboussinesq/addmeandensityanomaly.html) Add a mean-density anomaly to the existing fluid state.
    + [`initWithMeanDensityAnomaly`](/classes/transforms/wvtransformboussinesq/initwithmeandensityanomaly.html) Initialize the fluid state with a mean-density anomaly.
    + [`removeAllMeanDensityAnomaly`](/classes/transforms/wvtransformboussinesq/removeallmeandensityanomaly.html) remove all mean density anomalies
    + [`setMeanDensityAnomaly`](/classes/transforms/wvtransformboussinesq/setmeandensityanomaly.html) Set the mean-density-anomaly component.
+ Evaluate physical fields
  + Registered variables
    + [`hasVariableWithName`](/classes/transforms/wvtransformboussinesq/hasvariablewithname.html) Test whether state variables are registered by name.
    + [`summarizeVariables`](/classes/transforms/wvtransformboussinesq/summarizevariables.html) Print a table of registered state variables and cache status.
    + [`variableNames`](/classes/transforms/wvtransformboussinesq/variablenames.html) Return the names of all registered state variables.
    + [`variableWithName`](/classes/transforms/wvtransformboussinesq/variablewithname.html) Compute or retrieve one or more registered transform variables.
  + On the model grid
    + Velocity
      + [`u`](/classes/transforms/wvtransformboussinesq/u.html) x-component of the fluid velocity
      + [`v`](/classes/transforms/wvtransformboussinesq/v.html) y-component of the fluid velocity
      + [`w`](/classes/transforms/wvtransformboussinesq/w.html) z-component of the fluid velocity
    + Density and displacement
      + [`eta`](/classes/transforms/wvtransformboussinesq/eta.html) approximate isopycnal deviation
      + [`rho_bar`](/classes/transforms/wvtransformboussinesq/rho_bar.html) mean density
      + [`rho_e`](/classes/transforms/wvtransformboussinesq/rho_e.html) excess density
      + [`rho_nm`](/classes/transforms/wvtransformboussinesq/rho_nm.html) no-motion density profile
      + [`rho_nm0`](/classes/transforms/wvtransformboussinesq/rho_nm0.html) No-motion density profile sampled on the vertical grid.
      + [`rho_total`](/classes/transforms/wvtransformboussinesq/rho_total.html) total potential density
    + Pressure and surface fields
      + [`p`](/classes/transforms/wvtransformboussinesq/p.html) pressure anomaly
      + [`pi`](/classes/transforms/wvtransformboussinesq/pi.html) height anomaly
      + [`ssh`](/classes/transforms/wvtransformboussinesq/ssh.html) sea-surface height
      + [`ssu`](/classes/transforms/wvtransformboussinesq/ssu.html) x-component of the fluid velocity at the surface
      + [`ssv`](/classes/transforms/wvtransformboussinesq/ssv.html) y-component of the fluid velocity at the surface
    + Vorticity and geostrophic fields
      + [`psi`](/classes/transforms/wvtransformboussinesq/psi.html) geostrophic streamfunction
      + [`qgpv`](/classes/transforms/wvtransformboussinesq/qgpv.html) quasigeostrophic potential vorticity
      + [`zeta_x`](/classes/transforms/wvtransformboussinesq/zeta_x.html) x-component component of relative vorticity
      + [`zeta_y`](/classes/transforms/wvtransformboussinesq/zeta_y.html) y-component component of relative vorticity
      + [`zeta_z`](/classes/transforms/wvtransformboussinesq/zeta_z.html) vertical component of relative vorticity
  + At arbitrary positions
    + [`variableAtPositionWithName`](/classes/transforms/wvtransformboussinesq/variableatpositionwithname.html) Access dynamical variables at arbitrary positions in the domain.
  + Isopycnal utilities
    + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformboussinesq/placeparticlesonisopycnal.html) Return particle depths on the isopycnal identified by a no-motion depth.
+ Manage forcing and closures
  + [`addForcing`](/classes/transforms/wvtransformboussinesq/addforcing.html) Add forcing or closure objects to this transform.
  + [`forcing`](/classes/transforms/wvtransformboussinesq/forcing.html) array of WVForcing objects
  + [`forcingNames`](/classes/transforms/wvtransformboussinesq/forcingnames.html) Return forcing and closure names in application order.
  + [`forcingWithName`](/classes/transforms/wvtransformboussinesq/forcingwithname.html) Return registered forcing objects by name.
  + [`hasClosure`](/classes/transforms/wvtransformboussinesq/hasclosure.html) Whether a closure is currently attached to the transform.
  + [`hasForcingWithName`](/classes/transforms/wvtransformboussinesq/hasforcingwithname.html) Test whether forcing objects are registered by name.
  + [`removeAllForcing`](/classes/transforms/wvtransformboussinesq/removeallforcing.html) Remove every forcing and closure from this transform.
  + [`removeForcing`](/classes/transforms/wvtransformboussinesq/removeforcing.html) Remove the exact registered forcing objects.
  + [`setForcing`](/classes/transforms/wvtransformboussinesq/setforcing.html) Replace the complete forcing registry.
  + [`summarizeForcing`](/classes/transforms/wvtransformboussinesq/summarizeforcing.html) Print a table of registered forcing and closure objects.
+ Analyze the flow
  + Energy and summaries
    + [`inertialEnergy`](/classes/transforms/wvtransformboussinesq/inertialenergy.html) total energy of the inertial flow
    + [`mdaEnergy`](/classes/transforms/wvtransformboussinesq/mdaenergy.html) total energy of the mean density anomaly
    + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformboussinesq/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
    + [`waveEnergy`](/classes/transforms/wvtransformboussinesq/waveenergy.html) Total energy of the internal-gravity-wave flow.
    + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformboussinesq/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
    + [`exactTotalEnergy`](/classes/transforms/wvtransformboussinesq/exacttotalenergy.html) Nonlinear total energy evaluated from physical-space fields.
    + [`geostrophicEnergy`](/classes/transforms/wvtransformboussinesq/geostrophicenergy.html) total energy, geostrophic
    + [`hasMeanPressureDifference`](/classes/transforms/wvtransformboussinesq/hasmeanpressuredifference.html) Diagnose an MDA mean-pressure difference between the boundaries.
    + [`summarizeDegreesOfFreedom`](/classes/transforms/wvtransformboussinesq/summarizedegreesoffreedom.html) Summarize the spatial grid and active spectral degrees of freedom.
    + [`summarizeEnergyContent`](/classes/transforms/wvtransformboussinesq/summarizeenergycontent.html) displays a summary of the energy content of the fluid
    + [`summarizeModeEnergy`](/classes/transforms/wvtransformboussinesq/summarizemodeenergy.html) List the most energetic modes
    + [`totalEnergy`](/classes/transforms/wvtransformboussinesq/totalenergy.html) % - Topic: Energetics
    + [`totalEnergyOfFlowComponent`](/classes/transforms/wvtransformboussinesq/totalenergyofflowcomponent.html) Compute the energy carried by one flow component.
    + [`totalEnergySpatiallyIntegrated`](/classes/transforms/wvtransformboussinesq/totalenergyspatiallyintegrated.html) % - Topic: Energetics
  + Flow diagnostics
    + [`uvMax`](/classes/transforms/wvtransformboussinesq/uvmax.html) max horizontal fluid speed
    + [`wMax`](/classes/transforms/wvtransformboussinesq/wmax.html) max vertical fluid speed
  + Density validity
    + [`isDensityInValidRange`](/classes/transforms/wvtransformboussinesq/isdensityinvalidrange.html) Test whether total density remains within the no-motion density range.
  + Potential vorticity and enstrophy
    + [`exactPotentialEnstrophy`](/classes/transforms/wvtransformboussinesq/exactpotentialenstrophy.html) Exact potential enstrophy evaluated from available potential vorticity.
    + [`totalEnstrophy`](/classes/transforms/wvtransformboussinesq/totalenstrophy.html) Potential enstrophy computed from geostrophic coefficients.
    + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformboussinesq/totalenstrophyspatiallyintegrated.html) Potential enstrophy evaluated from the gridded QGPV field.
  + Spectra
    + Spectral fields
      + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformboussinesq/crossspectrumwithfgtransform.html) Compute a real modal cross-spectrum using the F-basis transform.
      + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformboussinesq/crossspectrumwithggtransform.html) Compute a real modal cross-spectrum using the G-basis transform.
      + [`spectrumWithFgTransform`](/classes/transforms/wvtransformboussinesq/spectrumwithfgtransform.html) Compute a modal autospectrum using the F-basis transform.
      + [`spectrumWithGgTransform`](/classes/transforms/wvtransformboussinesq/spectrumwithggtransform.html) Compute a modal autospectrum using the G-basis transform.
      + [`transformToKLAxes`](/classes/transforms/wvtransformboussinesq/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
    + Radial wavenumber
      + [`kRadial`](/classes/transforms/wvtransformboussinesq/kradial.html) radial (k,l) wavenumber on the WV grid
      + [`transformToRadialWavenumber`](/classes/transforms/wvtransformboussinesq/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
    + Frequency
      + [`convertFromWavenumberToFrequency`](/classes/transforms/wvtransformboussinesq/convertfromwavenumbertofrequency.html) Bin wave energy by vertical mode and intrinsic frequency
+ Save transform state
  + [`writeToFile`](/classes/transforms/wvtransformboussinesq/writetofile.html) Write this instance to NetCDF file.
+ Convert representations
  + Physical fields and coefficients
    + [`transformUVEtaToWaveVortex`](/classes/transforms/wvtransformboussinesq/transformuvetatowavevortex.html) transform fluid variables $$(u,v,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
    + [`transformUVWEtaToWaveVortex`](/classes/transforms/wvtransformboussinesq/transformuvwetatowavevortex.html) transform momentum variables $$(u,v,w,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
    + [`transformWaveVortexToUVWEta`](/classes/transforms/wvtransformboussinesq/transformwavevortextouvweta.html) transform wave-vortex coefficients $$(A_+,A_-,A_0)$$ to fluid variables $$(u,v,\eta)$$.
+ Differentiate and integrate fields
  + [`diffX`](/classes/transforms/wvtransformboussinesq/diffx.html) Differentiate a gridded field in the periodic x direction.
  + [`diffY`](/classes/transforms/wvtransformboussinesq/diffy.html) Differentiate a gridded field in the periodic y direction.
  + [`diffZF`](/classes/transforms/wvtransformboussinesq/diffzf.html) Differentiate an F-grid field with respect to z.
  + [`diffZG`](/classes/transforms/wvtransformboussinesq/diffzg.html) Differentiate a G-grid field with respect to z.
  + [`intZF`](/classes/transforms/wvtransformboussinesq/intzf.html) Return the first antiderivative of an F-representation.
  + [`intZG`](/classes/transforms/wvtransformboussinesq/intzg.html) Return the bottom-zero first antiderivative of a G-representation.
+ Inspect flow components
  + [`geostrophicComponent`](/classes/transforms/wvtransformboussinesq/geostrophiccomponent.html) returns the geostrophic flow component
  + [`waveComponent`](/classes/transforms/wvtransformboussinesq/wavecomponent.html) returns the internal gravity wave flow component
  + [`inertialComponent`](/classes/transforms/wvtransformboussinesq/inertialcomponent.html) returns the inertial oscillation flow component
  + [`mdaComponent`](/classes/transforms/wvtransformboussinesq/mdacomponent.html) returns the mean density anomaly component
  + [`flowComponentNames`](/classes/transforms/wvtransformboussinesq/flowcomponentnames.html) retrieve the names of all available variables
  + [`flowComponentWithName`](/classes/transforms/wvtransformboussinesq/flowcomponentwithname.html) retrieve a WVFlowComponent by name
  + [`flowComponents`](/classes/transforms/wvtransformboussinesq/flowcomponents.html) All registered physical and diagnostic flow components.
  + [`primaryFlowComponentNames`](/classes/transforms/wvtransformboussinesq/primaryflowcomponentnames.html) retrieve the names of all available variables
  + [`primaryFlowComponentWithName`](/classes/transforms/wvtransformboussinesq/primaryflowcomponentwithname.html) retrieve a WVPrimaryFlowComponent by name
  + [`primaryFlowComponents`](/classes/transforms/wvtransformboussinesq/primaryflowcomponents.html) Primary flow components that partition the active coefficient state.
  + [`summarizeFlowComponents`](/classes/transforms/wvtransformboussinesq/summarizeflowcomponents.html) Print a table of registered primary and diagnostic components.
  + [`totalFlowComponent`](/classes/transforms/wvtransformboussinesq/totalflowcomponent.html) Combined view of all primary flow components.
+ Inspect wave-vortex coefficients
  + Stored coefficients
    + [`Ap`](/classes/transforms/wvtransformboussinesq/ap.html) `Ap` stores the positive-frequency coefficients $$A_+^{k\ell j}$$ for internal gravity waves and the positive-frequency member of the paired inertial representation. The coefficients have units of velocity and use the transform's spectral layout.
    + [`Am`](/classes/transforms/wvtransformboussinesq/am.html) `Am` stores the negative-frequency coefficients $$A_-^{k\ell j}$$ for internal gravity waves and inertial oscillations. The coefficients have units of velocity and use the transform's spectral layout.
    + [`A0`](/classes/transforms/wvtransformboussinesq/a0.html) `A0` stores the zero-frequency coefficients $$A_0^{k\ell j}$$ with units of streamfunction, $$\mathrm{m^2\,s^{-1}}$$. It is the active coefficient family for geostrophic and quasigeostrophic flow and, on transforms that include it, the mean-density anomaly.
  + Coefficients at the current time
    + [`Apt`](/classes/transforms/wvtransformboussinesq/apt.html) `Apt` is the positive-frequency coefficient array evaluated at the current transform time:
    + [`Amt`](/classes/transforms/wvtransformboussinesq/amt.html) `Amt` is the negative-frequency coefficient array evaluated at the current transform time:
    + [`A0t`](/classes/transforms/wvtransformboussinesq/a0t.html) `A0t` is the zero-frequency coefficient array evaluated at the current transform time. On the supported $$f$$-plane transforms, `A0` has no linear phase winding and therefore
    + [`waveCoefficientsAtTimeT`](/classes/transforms/wvtransformboussinesq/wavecoefficientsattimet.html) Return positive- and negative-frequency coefficients at the current time.
  + Coefficient evolution
    + [`t0`](/classes/transforms/wvtransformboussinesq/t0.html) Reference time for the stored wave phases, in seconds.
    + [`t`](/classes/transforms/wvtransformboussinesq/t.html) Current transform time in seconds.
    + [`Omega`](/classes/transforms/wvtransformboussinesq/omega.html) Intrinsic angular frequency of each wave and inertial mode.
    + [`iOmega`](/classes/transforms/wvtransformboussinesq/iomega.html) Imaginary angular frequency, $$i\Omega$$, used for linear phase evolution.
    + [`phase`](/classes/transforms/wvtransformboussinesq/phase.html) unit-magnitude phase factor that advances `Ap` from `t0` to `t`
    + [`conjPhase`](/classes/transforms/wvtransformboussinesq/conjphase.html) conjugate phase factor that advances `Am` from `t0` to `t`
+ Create a related transform
  + [`spectralVariableWithResolution`](/classes/transforms/wvtransformboussinesq/spectralvariablewithresolution.html) create a new variable with different resolution
  + [`waveVortexTransformWithDoubleResolution`](/classes/transforms/wvtransformboussinesq/wavevortextransformwithdoubleresolution.html) create a new WVTransform with double resolution
  + [`waveVortexTransformWithExplicitAntialiasing`](/classes/transforms/wvtransformboussinesq/wavevortextransformwithexplicitantialiasing.html) Create an explicit-antialiasing transform with the same grid.
  + [`waveVortexTransformWithResolution`](/classes/transforms/wvtransformboussinesq/wavevortextransformwithresolution.html) Create the same transform family at a new resolution.
+ Extend a transform
  + Flow components
    + [`addFlowComponent`](/classes/transforms/wvtransformboussinesq/addflowcomponent.html) add a flow component and its standard variables
    + [`addPrimaryFlowComponent`](/classes/transforms/wvtransformboussinesq/addprimaryflowcomponent.html) add a primary flow component, automatically added to the flow
  + Operations and variables
    + [`addOperation`](/classes/transforms/wvtransformboussinesq/addoperation.html) Register one or more operations and their output variables.
    + [`operationWithName`](/classes/transforms/wvtransformboussinesq/operationwithname.html) retrieve a WVOperation by name
    + [`removeOperation`](/classes/transforms/wvtransformboussinesq/removeoperation.html) Remove the exact registered operation and its cached outputs.
+ Get package information
  + [`version`](/classes/transforms/wvtransformboussinesq/version.html) Installed WaveVortexModel version.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Projection and reconstruction coefficients
  + [`A0N`](/classes/transforms/wvtransformboussinesq/a0n.html) These projection coefficients map the density-displacement state variable onto $$A_0$$. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 3 entries of $$S^{-1}$$ for the primary internal-gravity-wave and geostrophic solutions in equation C5.
  + [`A0U`](/classes/transforms/wvtransformboussinesq/a0u.html) These projection coefficients map the $$u$$ state variable onto $$A_0$$. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 1 entries of $$S^{-1}$$ for the primary internal-gravity-wave and geostrophic solutions in equation C5.
  + [`A0V`](/classes/transforms/wvtransformboussinesq/a0v.html) These projection coefficients map the $$v$$ state variable onto $$A_0$$. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 2 entries of $$S^{-1}$$ for the primary internal-gravity-wave and geostrophic solutions in equation C5.
  + [`A0Z`](/classes/transforms/wvtransformboussinesq/a0z.html)
  + [`ApmD`](/classes/transforms/wvtransformboussinesq/apmd.html)
  + [`ApmN`](/classes/transforms/wvtransformboussinesq/apmn.html)
  + [`ApmW`](/classes/transforms/wvtransformboussinesq/apmw.html)
  + [`Feta`](/classes/transforms/wvtransformboussinesq/feta.html)
  + [`Fu`](/classes/transforms/wvtransformboussinesq/fu.html)
  + [`Fv`](/classes/transforms/wvtransformboussinesq/fv.html)
  + [`NA0`](/classes/transforms/wvtransformboussinesq/na0.html) These reconstruction coefficients map $$A_0$$ onto the density-displacement state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 3 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`NAm`](/classes/transforms/wvtransformboussinesq/nam.html) These reconstruction coefficients map $$A_-$$ onto the density-displacement state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 2 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`NAp`](/classes/transforms/wvtransformboussinesq/nap.html) These reconstruction coefficients map $$A_+$$ onto the density-displacement state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 1 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`P0`](/classes/transforms/wvtransformboussinesq/p0.html) Preconditioner for F, size(P)=[Nj 1]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`PA0`](/classes/transforms/wvtransformboussinesq/pa0.html)
  + [`Q0`](/classes/transforms/wvtransformboussinesq/q0.html) Preconditioner for G, size(Q)=[Nj 1]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`UA0`](/classes/transforms/wvtransformboussinesq/ua0.html) These reconstruction coefficients map $$A_0$$ onto the $$u$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 1, column 3 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`UAm`](/classes/transforms/wvtransformboussinesq/uam.html) These reconstruction coefficients map $$A_-$$ onto the $$u$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 1, column 2 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`UAp`](/classes/transforms/wvtransformboussinesq/uap.html) These reconstruction coefficients map $$A_+$$ onto the $$u$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 1, column 1 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`VA0`](/classes/transforms/wvtransformboussinesq/va0.html) These reconstruction coefficients map $$A_0$$ onto the $$v$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 2, column 3 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`VAm`](/classes/transforms/wvtransformboussinesq/vam.html) These reconstruction coefficients map $$A_-$$ onto the $$v$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 2, column 2 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`VAp`](/classes/transforms/wvtransformboussinesq/vap.html) These reconstruction coefficients map $$A_+$$ onto the $$v$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 2, column 1 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`WAm`](/classes/transforms/wvtransformboussinesq/wam.html) These reconstruction coefficients map $$A_-$$ onto the $$w$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 4, column 2 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`WAp`](/classes/transforms/wvtransformboussinesq/wap.html) These reconstruction coefficients map $$A_+$$ onto the $$w$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 4, column 1 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
+ Geometry and mode indexing
  + [`buildVerticalModeProjectionOperators`](/classes/transforms/wvtransformboussinesq/buildverticalmodeprojectionoperators.html)
  + [`conjugateDimension`](/classes/transforms/wvtransformboussinesq/conjugatedimension.html) assumed conjugate dimension
  + [`indexFromKLModeNumber`](/classes/transforms/wvtransformboussinesq/indexfromklmodenumber.html) return the linear index into k_wv and l_wv from a mode number
  + [`indexFromModeNumber`](/classes/transforms/wvtransformboussinesq/indexfrommodenumber.html) return the linear index into a spectral matrix given (k,l,j)
  + [`indicesFromDFTGridToWVGrid`](/classes/transforms/wvtransformboussinesq/indicesfromdftgridtowvgrid.html) indices to convert from DFT to WV grid
  + [`indicesFromWVGridToDFTGrid`](/classes/transforms/wvtransformboussinesq/indicesfromwvgridtodftgrid.html) indices to convert from WV to DFT grid
  + [`isValidConjugateKLModeNumber`](/classes/transforms/wvtransformboussinesq/isvalidconjugateklmodenumber.html) return a boolean indicating whether (k,l) is a valid conjugate WV mode number
  + [`isValidConjugateModeNumber`](/classes/transforms/wvtransformboussinesq/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid conjugate mode number
  + [`isValidKLModeNumber`](/classes/transforms/wvtransformboussinesq/isvalidklmodenumber.html) return a boolean indicating whether (k,l) is a valid WV mode number
  + [`isValidModeNumber`](/classes/transforms/wvtransformboussinesq/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
  + [`isValidPrimaryKLModeNumber`](/classes/transforms/wvtransformboussinesq/isvalidprimaryklmodenumber.html) return a boolean indicating whether (k,l) is a valid primary (non-conjugate) WV mode number
  + [`isValidPrimaryModeNumber`](/classes/transforms/wvtransformboussinesq/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid primary (non-conjugate) mode number
  + [`kMode_dft`](/classes/transforms/wvtransformboussinesq/kmode_dft.html) k mode-number on the DFT grid
  + [`kMode_wv`](/classes/transforms/wvtransformboussinesq/kmode_wv.html) k mode number on the WV grid
  + [`klModeNumberFromIndex`](/classes/transforms/wvtransformboussinesq/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
  + [`lMode_dft`](/classes/transforms/wvtransformboussinesq/lmode_dft.html) l mode-number on the DFT grid
  + [`lMode_wv`](/classes/transforms/wvtransformboussinesq/lmode_wv.html) l mode number on the WV grid
  + [`maskForAliasedModes`](/classes/transforms/wvtransformboussinesq/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
  + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformboussinesq/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
  + [`maskForNyquistModes`](/classes/transforms/wvtransformboussinesq/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
  + [`modeNumberFromIndex`](/classes/transforms/wvtransformboussinesq/modenumberfromindex.html) Return mode numbers for spectral linear indices.
  + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformboussinesq/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
  + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformboussinesq/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
  + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformboussinesq/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
  + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformboussinesq/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
  + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
  + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
+ Spectral transforms and operators
  + [`FMatrix`](/classes/transforms/wvtransformboussinesq/fmatrix.html) transformation matrix $$F_g$$
  + [`FinvMatrix`](/classes/transforms/wvtransformboussinesq/finvmatrix.html) transformation matrix $$F_g^{-1}$$
  + [`FwInvMatrix`](/classes/transforms/wvtransformboussinesq/fwinvmatrix.html) transformation matrix $$F_w^{-1}$$
  + [`FwMatrix`](/classes/transforms/wvtransformboussinesq/fwmatrix.html) transformation matrix $$F_w$$
  + [`GMatrix`](/classes/transforms/wvtransformboussinesq/gmatrix.html) transformation matrix $$G_g$$
  + [`GinvMatrix`](/classes/transforms/wvtransformboussinesq/ginvmatrix.html) transformation matrix $$G_g^{-1}$$
  + [`GwInvMatrix`](/classes/transforms/wvtransformboussinesq/gwinvmatrix.html) transformation matrix $$G_w^{-1}$$
  + [`GwMatrix`](/classes/transforms/wvtransformboussinesq/gwmatrix.html) transformation matrix $$G_w$$
  + [`PF0`](/classes/transforms/wvtransformboussinesq/pf0.html) size(PF,PG)=[Nj x Nz]
  + [`PF0inv`](/classes/transforms/wvtransformboussinesq/pf0inv.html) Transformation matrices
  + [`PFpm`](/classes/transforms/wvtransformboussinesq/pfpm.html) size(PF,PG)=[Nj x Nz x Nk]
  + [`PFpmInv`](/classes/transforms/wvtransformboussinesq/pfpminv.html) IGW transformation matrices
  + [`QG0`](/classes/transforms/wvtransformboussinesq/qg0.html) Preconditioned G-mode forward transformation
  + [`QG0inv`](/classes/transforms/wvtransformboussinesq/qg0inv.html) Preconditioned G-mode inverse transformation
  + [`QGpm`](/classes/transforms/wvtransformboussinesq/qgpm.html) Preconditioned G-mode forward transformation
  + [`QGpmInv`](/classes/transforms/wvtransformboussinesq/qgpminv.html) Preconditioned G-mode inverse transformation
  + [`QGwg`](/classes/transforms/wvtransformboussinesq/qgwg.html) size(PF,PG)=[Nj x Nj x Nk]
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformboussinesq/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformboussinesq/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`fastTransform`](/classes/transforms/wvtransformboussinesq/fasttransform.html) fast transform object
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformboussinesq/transformfromspatialdomainwithfio.html)
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformboussinesq/transformfromspatialdomainwithfourier.html)
  + [`transformFromSpatialDomainWithG_w`](/classes/transforms/wvtransformboussinesq/transformfromspatialdomainwithg_w.html)
  + [`transformToSpatialDomainWithFg`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithfg.html) arguments
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithfourieratposition.html)
  + [`transformToSpatialDomainWithFw`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithfw.html)
  + [`transformToSpatialDomainWithGg`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithgg.html) arguments
  + [`transformToSpatialDomainWithGw`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithgw.html)
  + [`transformWithG_wg`](/classes/transforms/wvtransformboussinesq/transformwithg_wg.html)
+ Nonlinear flux and forcing internals
  + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformboussinesq/enstrophyfluxfromf0.html)
  + [`fluxForForcing`](/classes/transforms/wvtransformboussinesq/fluxforforcing.html)
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformboussinesq/qgpvfluxfromf0.html)
  + [`spatialFluxForForcingWithName`](/classes/transforms/wvtransformboussinesq/spatialfluxforforcingwithname.html)
+ Persistence internals
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformboussinesq/classrequiredpropertynames.html)
  + [`geometryFromGroup`](/classes/transforms/wvtransformboussinesq/geometryfromgroup.html)
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformboussinesq/namesofrequiredpropertiesforgeometry.html)
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformboussinesq/namesofrequiredpropertiesforrotatingfplane.html)
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformboussinesq/namesofrequiredpropertiesfortransform.html)
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformboussinesq/namesoftransformvariables.html)
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformboussinesq/newnonrequiredpropertynames.html)
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformboussinesq/newrequiredpropertynames.html)
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformboussinesq/requiredpropertiesforgeometryfromgroup.html)
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformboussinesq/requiredpropertiesforrotatingfplanefromgroup.html)
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformboussinesq/requiredpropertiesfortransformfromgroup.html)
  + [`transformFromGroup`](/classes/transforms/wvtransformboussinesq/transformfromgroup.html)
+ Caches and registries
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformboussinesq/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformboussinesq/propertyannotationsforrotatingfplane.html)
+ Class internals
  + [`Ddelta`](/classes/transforms/wvtransformboussinesq/ddelta.html)
  + [`K2unique`](/classes/transforms/wvtransformboussinesq/k2unique.html) unique squared-wavenumbers
  + [`K2uniqueK2Map`](/classes/transforms/wvtransformboussinesq/k2uniquek2map.html) cell array Nk in length. Each cell contains indices back to K2
  + [`Nk_dft`](/classes/transforms/wvtransformboussinesq/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
  + [`Nl_dft`](/classes/transforms/wvtransformboussinesq/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
  + [`Ppm`](/classes/transforms/wvtransformboussinesq/ppm.html) Preconditioner for F, size(P)=[Nj x Nk]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`Qpm`](/classes/transforms/wvtransformboussinesq/qpm.html) Preconditioner for G, size(Q)=[Nj x Nk]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`chebfunForZArray`](/classes/transforms/wvtransformboussinesq/chebfunforzarray.html)
  + [`delta_uhat`](/classes/transforms/wvtransformboussinesq/delta_uhat.html)
  + [`delta_vhat`](/classes/transforms/wvtransformboussinesq/delta_vhat.html)
  + [`dftConjugateIndices2D`](/classes/transforms/wvtransformboussinesq/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
  + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformboussinesq/dftprimaryindices2d.html) index into the DFT grid of each WV mode
  + [`iK2unique`](/classes/transforms/wvtransformboussinesq/ik2unique.html) map from 2-dim K2, to 1-dim K2unique
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformboussinesq/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isHermitian`](/classes/transforms/wvtransformboussinesq/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`k_dft`](/classes/transforms/wvtransformboussinesq/k_dft.html) k wavenumber dimension on the DFT grid
  + [`kl`](/classes/transforms/wvtransformboussinesq/kl.html) wavenumber dimension
  + [`l_dft`](/classes/transforms/wvtransformboussinesq/l_dft.html) l wavenumber dimension on the DFT grid
  + [`maxFg`](/classes/transforms/wvtransformboussinesq/maxfg.html)
  + [`maxFw`](/classes/transforms/wvtransformboussinesq/maxfw.html)
  + [`nK2unique`](/classes/transforms/wvtransformboussinesq/nk2unique.html) number of unique squared-wavenumbers
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformboussinesq/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`setConjugateToUnity`](/classes/transforms/wvtransformboussinesq/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
  + [`shouldExcludeConjugates`](/classes/transforms/wvtransformboussinesq/shouldexcludeconjugates.html) whether the WV grid excludes redundant Hermitian-conjugate wavenumbers
  + [`shouldExcludeNyquist`](/classes/transforms/wvtransformboussinesq/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformboussinesq/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformboussinesq/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors
  + [`wvBuffer`](/classes/transforms/wvtransformboussinesq/wvbuffer.html)


---