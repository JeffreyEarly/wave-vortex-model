---
layout: default
title: WVTransformHydrostatic
has_children: false
has_toc: false
mathjax: true
parent: Transforms
grand_parent: Class documentation
nav_order: 3
---

#  WVTransformHydrostatic

Decompose hydrostatic variable-stratification flow into wave and geostrophic components.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransformHydrostatic < <a href="/classes/transforms/wvtransform/" title="WVTransform">WVTransform</a></code></pre></div></div>

## Overview

To initialize `WVTransformHydrostatic`, specify the domain size, the
number of grid points, and either
the density profile or the stratification profile.

```matlab
N0 = 3*2*pi/3600;
L_gm = 1300;
N2 = @(z) N0*N0*exp(2*z/L_gm);
wvt = WVTransformHydrostatic([100e3,100e3,4000],[64,64,65],N2Function=N2,latitude=30);
```

The transform state is stored in [`Ap`](/classes/transforms/wvtransform/ap.html),
[`Am`](/classes/transforms/wvtransform/am.html), and
[`A0`](/classes/transforms/wvtransform/a0.html). Their current-time
views are `Apt`, `Amt`, and `A0t`.




## Topics
+ Create and restore a transform
  + [`WVTransformHydrostatic`](/classes/transforms/wvtransformhydrostatic/wvtransformhydrostatic.html) Create a hydrostatic wave-vortex transform for variable stratification.
  + [`waveVortexTransformFromFile`](/classes/transforms/wvtransformhydrostatic/wavevortextransformfromfile.html) Initialize a WVTransformHydrostatic instance from an existing file
+ Inspect the domain
  + Physical environment
    + Planetary rotation
      + [`beta`](/classes/transforms/wvtransformhydrostatic/beta.html) Meridional gradient of the Coriolis parameter.
      + [`f`](/classes/transforms/wvtransformhydrostatic/f.html) Coriolis parameter in radians per second.
      + [`inertialPeriod`](/classes/transforms/wvtransformhydrostatic/inertialperiod.html) Inertial period in seconds.
      + [`latitude`](/classes/transforms/wvtransformhydrostatic/latitude.html) Central latitude of the rotating domain in degrees north.
      + [`planetaryRadius`](/classes/transforms/wvtransformhydrostatic/planetaryradius.html) Radius of the rotating planetary body in meters.
      + [`rotationRate`](/classes/transforms/wvtransformhydrostatic/rotationrate.html) Planetary rotation rate in radians per second.
    + Stratification and reference density
      + [`N2`](/classes/transforms/wvtransformhydrostatic/n2.html) Buoyancy frequency squared sampled on the vertical grid.
      + [`N2Function`](/classes/transforms/wvtransformhydrostatic/n2function.html) Function returning buoyancy frequency squared at requested depths.
      + [`buoyancyPeriod`](/classes/transforms/wvtransformhydrostatic/buoyancyperiod.html) Shortest buoyancy period in seconds.
      + [`dLnN2`](/classes/transforms/wvtransformhydrostatic/dlnn2.html) $$\partial_z \ln N^2$$, vertical derivative of the logarithm of squared buoyancy frequency
      + [`rho0`](/classes/transforms/wvtransformhydrostatic/rho0.html) Boussinesq reference density in kilograms per cubic meter.
      + [`rhoFunction`](/classes/transforms/wvtransformhydrostatic/rhofunction.html) Function returning the no-motion density profile at requested depths.
      + [`shouldUseTrueNoMotionProfile`](/classes/transforms/wvtransformhydrostatic/shouldusetruenomotionprofile.html) Whether density diagnostics use the supplied no-motion profile directly.
    + Gravity
      + [`g`](/classes/transforms/wvtransformhydrostatic/g.html) Gravitational acceleration in meters per second squared.
  + Spatial grid
    + Coordinate axes
      + [`x`](/classes/transforms/wvtransformhydrostatic/x.html) Periodic x-coordinate axis in meters.
      + [`y`](/classes/transforms/wvtransformhydrostatic/y.html) Periodic y-coordinate axis in meters.
      + [`z`](/classes/transforms/wvtransformhydrostatic/z.html) Three-dimensional vertical-coordinate array in meters.
    + Coordinate arrays
      + [`X`](/classes/transforms/wvtransformhydrostatic/x_.html) Gridded x-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`Y`](/classes/transforms/wvtransformhydrostatic/y_.html) Gridded y-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`Z`](/classes/transforms/wvtransformhydrostatic/z_.html) Gridded vertical-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`xyzGrid`](/classes/transforms/wvtransformhydrostatic/xyzgrid.html) Return the three-dimensional spatial coordinate arrays.
    + Domain dimensions
      + [`Lx`](/classes/transforms/wvtransformhydrostatic/lx.html) Periodic domain length in the x direction.
      + [`Ly`](/classes/transforms/wvtransformhydrostatic/ly.html) Periodic domain length in the y direction.
      + [`Lz`](/classes/transforms/wvtransformhydrostatic/lz.html) Vertical domain depth in meters.
    + Resolution and shape
      + [`Nx`](/classes/transforms/wvtransformhydrostatic/nx.html) Number of spatial grid points in the x direction.
      + [`Ny`](/classes/transforms/wvtransformhydrostatic/ny.html) Number of spatial grid points in the y direction.
      + [`Nz`](/classes/transforms/wvtransformhydrostatic/nz.html) Number of vertical spatial grid points.
      + [`spatialMatrixSize`](/classes/transforms/wvtransformhydrostatic/spatialmatrixsize.html) Shape of a gridded physical-space field.
    + Quadrature and integration
      + [`z_int`](/classes/transforms/wvtransformhydrostatic/z_int.html) Vertical quadrature weights in meters.
      + [`volumeIntegral`](/classes/transforms/wvtransformhydrostatic/volumeintegral.html) Compute the horizontally averaged depth integral of a scalar field.
  + Spectral grid
    + Axes and spacing
      + [`kAxis`](/classes/transforms/wvtransformhydrostatic/kaxis.html) Centered x-direction angular-wavenumber axis.
      + [`lAxis`](/classes/transforms/wvtransformhydrostatic/laxis.html) Centered y-direction angular-wavenumber axis.
      + [`j`](/classes/transforms/wvtransformhydrostatic/j.html) Vertical-mode index axis.
      + [`dk`](/classes/transforms/wvtransformhydrostatic/dk.html) Spacing of the x-direction angular-wavenumber axis.
      + [`dl`](/classes/transforms/wvtransformhydrostatic/dl.html) Spacing of the y-direction angular-wavenumber axis.
    + Coordinate arrays
      + [`k`](/classes/transforms/wvtransformhydrostatic/k.html) Stored x-direction angular wavenumbers on the compact WV grid.
      + [`l`](/classes/transforms/wvtransformhydrostatic/l.html) Stored y-direction angular wavenumbers on the compact WV grid.
      + [`K`](/classes/transforms/wvtransformhydrostatic/k_.html) X-direction angular-wavenumber array in rad/m with shape `[Nj Nkl]`.
      + [`L`](/classes/transforms/wvtransformhydrostatic/l_.html) Y-direction angular-wavenumber array in rad/m with shape `[Nj Nkl]`.
      + [`J`](/classes/transforms/wvtransformhydrostatic/j_.html) Dimensionless vertical-mode index array with shape `[Nj Nkl]`.
      + [`kljGrid`](/classes/transforms/wvtransformhydrostatic/kljgrid.html) Return spectral-coordinate arrays in wave-vortex layout.
    + Horizontal wavenumber geometry
      + [`Kh`](/classes/transforms/wvtransformhydrostatic/kh.html) Horizontal angular-wavenumber magnitude on the coefficient grid.
      + [`K2`](/classes/transforms/wvtransformhydrostatic/k2.html) Squared horizontal angular wavenumber on the coefficient grid.
    + Resolution and shape
      + [`Nj`](/classes/transforms/wvtransformhydrostatic/nj.html) Number of retained vertical modes.
      + [`Nkl`](/classes/transforms/wvtransformhydrostatic/nkl.html) Number of retained compact horizontal-wavenumber columns.
      + [`spectralMatrixSize`](/classes/transforms/wvtransformhydrostatic/spectralmatrixsize.html) Shape of a wave-vortex coefficient array.
      + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformhydrostatic/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
      + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformhydrostatic/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
      + [`effectiveJMax`](/classes/transforms/wvtransformhydrostatic/effectivejmax.html) Largest active vertical-mode index.
    + Vertical modes and scaling
      + [`verticalModes`](/classes/transforms/wvtransformhydrostatic/verticalmodes.html) Vertical-mode solution used to construct the transform basis.
      + [`h_0`](/classes/transforms/wvtransformhydrostatic/h_0.html) Geostrophic equivalent-depth scale for each vertical mode.
      + [`h_pm`](/classes/transforms/wvtransformhydrostatic/h_pm.html) Wave equivalent depth on the spectral grid.
      + [`Lr2`](/classes/transforms/wvtransformhydrostatic/lr2.html) Squared Rossby deformation radius in square meters.
      + [`waveModeVerticalStructureAtIndex`](/classes/transforms/wvtransformhydrostatic/wavemodeverticalstructureatindex.html) Return wave vertical-structure factors at one vertical grid index.
  + Transform configuration
    + [`isHydrostatic`](/classes/transforms/wvtransformhydrostatic/ishydrostatic.html) Whether the transform uses the hydrostatic approximation.
    + [`shouldAntialias`](/classes/transforms/wvtransformhydrostatic/shouldantialias.html) Whether the spectral grid excludes modes that alias quadratic products.
+ Initialize the flow
  + General initialization
    + [`addRandomFlow`](/classes/transforms/wvtransformhydrostatic/addrandomflow.html) add randomized flow to the existing state
    + [`addUVEta`](/classes/transforms/wvtransformhydrostatic/adduveta.html) add $$(u,v,\eta)$$ to the existing values
    + [`initFromNetCDFFile`](/classes/transforms/wvtransformhydrostatic/initfromnetcdffile.html) initialize the flow from a NetCDF file
    + [`initWithRandomFlow`](/classes/transforms/wvtransformhydrostatic/initwithrandomflow.html) initialize with a random flow state
    + [`initWithUVEta`](/classes/transforms/wvtransformhydrostatic/initwithuveta.html) initialize with fluid variables $$(u,v,\eta)$$
    + [`initWithUVRho`](/classes/transforms/wvtransformhydrostatic/initwithuvrho.html) initialize with fluid variables $$(u,v,\rho)$$
    + [`removeAll`](/classes/transforms/wvtransformhydrostatic/removeall.html) removes all energy from the model
  + Waves
    + Individual modes
      + [`addWaveModes`](/classes/transforms/wvtransformhydrostatic/addwavemodes.html) add amplitudes of the given wave modes
      + [`initWithWaveModes`](/classes/transforms/wvtransformhydrostatic/initwithwavemodes.html) initialize with the given wave modes
      + [`removeAllWaves`](/classes/transforms/wvtransformhydrostatic/removeallwaves.html) removes all wave from the model, including inertial oscillations
      + [`setWaveModes`](/classes/transforms/wvtransformhydrostatic/setwavemodes.html) set amplitudes of the given wave modes
    + Wave spectra
      + [`addGMSpectrum`](/classes/transforms/wvtransformhydrostatic/addgmspectrum.html) add waves following a Garrett-Munk spectrum
      + [`addWavesWithFrequencySpectrum`](/classes/transforms/wvtransformhydrostatic/addwaveswithfrequencyspectrum.html) add waves with a specified frequency spectrum
      + [`initWavesWithFrequencySpectrum`](/classes/transforms/wvtransformhydrostatic/initwaveswithfrequencyspectrum.html) initialize with waves of a specified frequency spectrum
      + [`initWithAlternativeSpectrum`](/classes/transforms/wvtransformhydrostatic/initwithalternativespectrum.html) initialize with an alternative formulation of the GM spectrum in the wavenumber domain.
      + [`initWithGMSpectrum`](/classes/transforms/wvtransformhydrostatic/initwithgmspectrum.html) initialize the wave field following a Garrett-Munk spectrum
  + Inertial oscillations
    + [`addInertialMotions`](/classes/transforms/wvtransformhydrostatic/addinertialmotions.html) add inertial motions to existing inertial motions
    + [`initWithInertialMotions`](/classes/transforms/wvtransformhydrostatic/initwithinertialmotions.html) initialize with inertial motions
    + [`removeAllInertialMotions`](/classes/transforms/wvtransformhydrostatic/removeallinertialmotions.html) remove all inertial motions
    + [`setInertialMotions`](/classes/transforms/wvtransformhydrostatic/setinertialmotions.html) set inertial motions
  + Geostrophic motions
    + [`initWithGeostrophicStreamfunction`](/classes/transforms/wvtransformhydrostatic/initwithgeostrophicstreamfunction.html) initialize with a geostrophic streamfunction
    + [`setGeostrophicStreamfunction`](/classes/transforms/wvtransformhydrostatic/setgeostrophicstreamfunction.html) set a geostrophic streamfunction
    + [`addGeostrophicStreamfunction`](/classes/transforms/wvtransformhydrostatic/addgeostrophicstreamfunction.html) add a geostrophic streamfunction to existing geostrophic motions
    + [`setGeostrophicModes`](/classes/transforms/wvtransformhydrostatic/setgeostrophicmodes.html) set amplitudes of the given geostrophic modes
    + [`addGeostrophicModes`](/classes/transforms/wvtransformhydrostatic/addgeostrophicmodes.html) add amplitudes of the given geostrophic modes
    + [`removeAllGeostrophicMotions`](/classes/transforms/wvtransformhydrostatic/removeallgeostrophicmotions.html) remove all geostrophic motions
  + Mean density anomalies
    + [`addMeanDensityAnomaly`](/classes/transforms/wvtransformhydrostatic/addmeandensityanomaly.html) Add a mean-density anomaly to the existing fluid state.
    + [`initWithMeanDensityAnomaly`](/classes/transforms/wvtransformhydrostatic/initwithmeandensityanomaly.html) Initialize the fluid state with a mean-density anomaly.
    + [`removeAllMeanDensityAnomaly`](/classes/transforms/wvtransformhydrostatic/removeallmeandensityanomaly.html) remove all mean density anomalies
    + [`setMeanDensityAnomaly`](/classes/transforms/wvtransformhydrostatic/setmeandensityanomaly.html) Set the mean-density-anomaly component.
+ Evaluate physical fields
  + Registered variables
    + [`hasVariableWithName`](/classes/transforms/wvtransformhydrostatic/hasvariablewithname.html) Test whether state variables are registered by name.
    + [`summarizeVariables`](/classes/transforms/wvtransformhydrostatic/summarizevariables.html) Print a table of registered state variables and cache status.
    + [`variableNames`](/classes/transforms/wvtransformhydrostatic/variablenames.html) Return the names of all registered state variables.
    + [`variableWithName`](/classes/transforms/wvtransformhydrostatic/variablewithname.html) Compute or retrieve one or more registered transform variables.
  + On the model grid
    + Velocity
      + [`u`](/classes/transforms/wvtransformhydrostatic/u.html) x-component of the fluid velocity
      + [`v`](/classes/transforms/wvtransformhydrostatic/v.html) y-component of the fluid velocity
      + [`w`](/classes/transforms/wvtransformhydrostatic/w.html) z-component of the fluid velocity
    + Density and displacement
      + [`eta`](/classes/transforms/wvtransformhydrostatic/eta.html) approximate isopycnal deviation
      + [`rho_bar`](/classes/transforms/wvtransformhydrostatic/rho_bar.html) mean density
      + [`rho_e`](/classes/transforms/wvtransformhydrostatic/rho_e.html) excess density
      + [`rho_nm`](/classes/transforms/wvtransformhydrostatic/rho_nm.html) no-motion density profile
      + [`rho_nm0`](/classes/transforms/wvtransformhydrostatic/rho_nm0.html) No-motion density profile sampled on the vertical grid.
      + [`rho_total`](/classes/transforms/wvtransformhydrostatic/rho_total.html) total potential density
    + Pressure and surface fields
      + [`p`](/classes/transforms/wvtransformhydrostatic/p.html) pressure anomaly
      + [`pi`](/classes/transforms/wvtransformhydrostatic/pi.html) height anomaly
      + [`ssh`](/classes/transforms/wvtransformhydrostatic/ssh.html) sea-surface height
      + [`ssu`](/classes/transforms/wvtransformhydrostatic/ssu.html) x-component of the fluid velocity at the surface
      + [`ssv`](/classes/transforms/wvtransformhydrostatic/ssv.html) y-component of the fluid velocity at the surface
    + Vorticity and geostrophic fields
      + [`psi`](/classes/transforms/wvtransformhydrostatic/psi.html) geostrophic streamfunction
      + [`qgpv`](/classes/transforms/wvtransformhydrostatic/qgpv.html) quasigeostrophic potential vorticity
      + [`zeta_x`](/classes/transforms/wvtransformhydrostatic/zeta_x.html) x-component component of relative vorticity
      + [`zeta_y`](/classes/transforms/wvtransformhydrostatic/zeta_y.html) y-component component of relative vorticity
      + [`zeta_z`](/classes/transforms/wvtransformhydrostatic/zeta_z.html) vertical component of relative vorticity
  + At arbitrary positions
    + [`variableAtPositionWithName`](/classes/transforms/wvtransformhydrostatic/variableatpositionwithname.html) Access dynamical variables at arbitrary positions in the domain.
  + Isopycnal utilities
    + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformhydrostatic/placeparticlesonisopycnal.html) Return particle depths on the isopycnal identified by a no-motion depth.
+ Manage forcing and closures
  + [`addForcing`](/classes/transforms/wvtransformhydrostatic/addforcing.html) Add forcing or closure objects to this transform.
  + [`forcing`](/classes/transforms/wvtransformhydrostatic/forcing.html) array of WVForcing objects
  + [`forcingNames`](/classes/transforms/wvtransformhydrostatic/forcingnames.html) Return forcing and closure names in application order.
  + [`forcingWithName`](/classes/transforms/wvtransformhydrostatic/forcingwithname.html) Return registered forcing objects by name.
  + [`hasClosure`](/classes/transforms/wvtransformhydrostatic/hasclosure.html) Whether a closure is currently attached to the transform.
  + [`hasForcingWithName`](/classes/transforms/wvtransformhydrostatic/hasforcingwithname.html) Test whether forcing objects are registered by name.
  + [`removeAllForcing`](/classes/transforms/wvtransformhydrostatic/removeallforcing.html) Remove every forcing and closure from this transform.
  + [`removeForcing`](/classes/transforms/wvtransformhydrostatic/removeforcing.html) Remove the exact registered forcing objects.
  + [`setForcing`](/classes/transforms/wvtransformhydrostatic/setforcing.html) Replace the complete forcing registry.
  + [`summarizeForcing`](/classes/transforms/wvtransformhydrostatic/summarizeforcing.html) Print a table of registered forcing and closure objects.
+ Analyze the flow
  + Energy and summaries
    + [`inertialEnergy`](/classes/transforms/wvtransformhydrostatic/inertialenergy.html) total energy of the inertial flow
    + [`mdaEnergy`](/classes/transforms/wvtransformhydrostatic/mdaenergy.html) total energy of the mean density anomaly
    + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformhydrostatic/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
    + [`waveEnergy`](/classes/transforms/wvtransformhydrostatic/waveenergy.html) Total energy of the internal-gravity-wave flow.
    + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformhydrostatic/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
    + [`exactTotalEnergy`](/classes/transforms/wvtransformhydrostatic/exacttotalenergy.html) Nonlinear total energy evaluated from physical-space fields.
    + [`geostrophicEnergy`](/classes/transforms/wvtransformhydrostatic/geostrophicenergy.html) total energy, geostrophic
    + [`hasMeanPressureDifference`](/classes/transforms/wvtransformhydrostatic/hasmeanpressuredifference.html) Diagnose an MDA mean-pressure difference between the boundaries.
    + [`summarizeDegreesOfFreedom`](/classes/transforms/wvtransformhydrostatic/summarizedegreesoffreedom.html) Summarize the spatial grid and active spectral degrees of freedom.
    + [`summarizeEnergyContent`](/classes/transforms/wvtransformhydrostatic/summarizeenergycontent.html) displays a summary of the energy content of the fluid
    + [`summarizeModeEnergy`](/classes/transforms/wvtransformhydrostatic/summarizemodeenergy.html) List the most energetic modes
    + [`totalEnergy`](/classes/transforms/wvtransformhydrostatic/totalenergy.html) % - Topic: Energetics
    + [`totalEnergyOfFlowComponent`](/classes/transforms/wvtransformhydrostatic/totalenergyofflowcomponent.html) Compute the energy carried by one flow component.
    + [`totalEnergySpatiallyIntegrated`](/classes/transforms/wvtransformhydrostatic/totalenergyspatiallyintegrated.html) % - Topic: Energetics
  + Flow diagnostics
    + [`uvMax`](/classes/transforms/wvtransformhydrostatic/uvmax.html) max horizontal fluid speed
    + [`wMax`](/classes/transforms/wvtransformhydrostatic/wmax.html) max vertical fluid speed
  + Density validity
    + [`isDensityInValidRange`](/classes/transforms/wvtransformhydrostatic/isdensityinvalidrange.html) Test whether total density remains within the no-motion density range.
  + Potential vorticity and enstrophy
    + [`exactPotentialEnstrophy`](/classes/transforms/wvtransformhydrostatic/exactpotentialenstrophy.html) Exact potential enstrophy evaluated from available potential vorticity.
    + [`totalEnstrophy`](/classes/transforms/wvtransformhydrostatic/totalenstrophy.html) Potential enstrophy computed from geostrophic coefficients.
    + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformhydrostatic/totalenstrophyspatiallyintegrated.html) Potential enstrophy evaluated from the gridded QGPV field.
  + Spectra
    + Spectral fields
      + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformhydrostatic/crossspectrumwithfgtransform.html) Compute a real modal cross-spectrum using the F-basis transform.
      + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformhydrostatic/crossspectrumwithggtransform.html) Compute a real modal cross-spectrum using the G-basis transform.
      + [`spectrumWithFgTransform`](/classes/transforms/wvtransformhydrostatic/spectrumwithfgtransform.html) Compute a modal autospectrum using the F-basis transform.
      + [`spectrumWithGgTransform`](/classes/transforms/wvtransformhydrostatic/spectrumwithggtransform.html) Compute a modal autospectrum using the G-basis transform.
      + [`transformToKLAxes`](/classes/transforms/wvtransformhydrostatic/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
    + Radial wavenumber
      + [`kRadial`](/classes/transforms/wvtransformhydrostatic/kradial.html) radial (k,l) wavenumber on the WV grid
      + [`transformToRadialWavenumber`](/classes/transforms/wvtransformhydrostatic/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
    + Frequency
      + [`convertFromWavenumberToFrequency`](/classes/transforms/wvtransformhydrostatic/convertfromwavenumbertofrequency.html) Bin wave energy by vertical mode and intrinsic frequency
+ Save transform state
  + [`writeToFile`](/classes/transforms/wvtransformhydrostatic/writetofile.html) Write this instance to NetCDF file.
+ Convert representations
  + Physical fields and coefficients
    + [`transformUVEtaToWaveVortex`](/classes/transforms/wvtransformhydrostatic/transformuvetatowavevortex.html) transform fluid variables $$(u,v,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
    + [`transformWaveVortexToUVWEta`](/classes/transforms/wvtransformhydrostatic/transformwavevortextouvweta.html) transform wave-vortex coefficients $$(A_+,A_-,A_0)$$ to fluid variables $$(u,v,\eta)$$.
+ Differentiate and integrate fields
  + [`diffX`](/classes/transforms/wvtransformhydrostatic/diffx.html) Differentiate a gridded field in the periodic x direction.
  + [`diffY`](/classes/transforms/wvtransformhydrostatic/diffy.html) Differentiate a gridded field in the periodic y direction.
  + [`diffZF`](/classes/transforms/wvtransformhydrostatic/diffzf.html) Differentiate an F-grid field with respect to z.
  + [`diffZG`](/classes/transforms/wvtransformhydrostatic/diffzg.html) Differentiate a G-grid field with respect to z.
  + [`intZF`](/classes/transforms/wvtransformhydrostatic/intzf.html) Return the first antiderivative of an F-representation.
  + [`intZG`](/classes/transforms/wvtransformhydrostatic/intzg.html) Return the bottom-zero first antiderivative of a G-representation.
+ Inspect flow components
  + [`geostrophicComponent`](/classes/transforms/wvtransformhydrostatic/geostrophiccomponent.html) returns the geostrophic flow component
  + [`waveComponent`](/classes/transforms/wvtransformhydrostatic/wavecomponent.html) returns the internal gravity wave flow component
  + [`inertialComponent`](/classes/transforms/wvtransformhydrostatic/inertialcomponent.html) returns the inertial oscillation flow component
  + [`mdaComponent`](/classes/transforms/wvtransformhydrostatic/mdacomponent.html) returns the mean density anomaly component
  + [`flowComponentNames`](/classes/transforms/wvtransformhydrostatic/flowcomponentnames.html) retrieve the names of all available variables
  + [`flowComponentWithName`](/classes/transforms/wvtransformhydrostatic/flowcomponentwithname.html) retrieve a WVFlowComponent by name
  + [`flowComponents`](/classes/transforms/wvtransformhydrostatic/flowcomponents.html) All registered physical and diagnostic flow components.
  + [`primaryFlowComponentNames`](/classes/transforms/wvtransformhydrostatic/primaryflowcomponentnames.html) retrieve the names of all available variables
  + [`primaryFlowComponentWithName`](/classes/transforms/wvtransformhydrostatic/primaryflowcomponentwithname.html) retrieve a WVPrimaryFlowComponent by name
  + [`primaryFlowComponents`](/classes/transforms/wvtransformhydrostatic/primaryflowcomponents.html) Primary flow components that partition the active coefficient state.
  + [`summarizeFlowComponents`](/classes/transforms/wvtransformhydrostatic/summarizeflowcomponents.html) Print a table of registered primary and diagnostic components.
  + [`totalFlowComponent`](/classes/transforms/wvtransformhydrostatic/totalflowcomponent.html) Combined view of all primary flow components.
+ Inspect wave-vortex coefficients
  + Stored coefficients
    + [`Ap`](/classes/transforms/wvtransformhydrostatic/ap.html) `Ap` stores the positive-frequency coefficients $$A_+^{k\ell j}$$ for internal gravity waves and the positive-frequency member of the paired inertial representation. The coefficients have units of velocity and use the transform's spectral layout.
    + [`Am`](/classes/transforms/wvtransformhydrostatic/am.html) `Am` stores the negative-frequency coefficients $$A_-^{k\ell j}$$ for internal gravity waves and inertial oscillations. The coefficients have units of velocity and use the transform's spectral layout.
    + [`A0`](/classes/transforms/wvtransformhydrostatic/a0.html) `A0` stores the zero-frequency coefficients $$A_0^{k\ell j}$$ with units of streamfunction, $$\mathrm{m^2\,s^{-1}}$$. It is the active coefficient family for geostrophic and quasigeostrophic flow and, on transforms that include it, the mean-density anomaly.
  + Coefficients at the current time
    + [`Apt`](/classes/transforms/wvtransformhydrostatic/apt.html) `Apt` is the positive-frequency coefficient array evaluated at the current transform time:
    + [`Amt`](/classes/transforms/wvtransformhydrostatic/amt.html) `Amt` is the negative-frequency coefficient array evaluated at the current transform time:
    + [`A0t`](/classes/transforms/wvtransformhydrostatic/a0t.html) `A0t` is the zero-frequency coefficient array evaluated at the current transform time. On the supported $$f$$-plane transforms, `A0` has no linear phase winding and therefore
    + [`waveCoefficientsAtTimeT`](/classes/transforms/wvtransformhydrostatic/wavecoefficientsattimet.html) Return positive- and negative-frequency coefficients at the current time.
  + Coefficient evolution
    + [`t0`](/classes/transforms/wvtransformhydrostatic/t0.html) Reference time for the stored wave phases, in seconds.
    + [`t`](/classes/transforms/wvtransformhydrostatic/t.html) Current transform time in seconds.
    + [`Omega`](/classes/transforms/wvtransformhydrostatic/omega.html) Intrinsic angular frequency of each wave and inertial mode.
    + [`iOmega`](/classes/transforms/wvtransformhydrostatic/iomega.html) Imaginary angular frequency, $$i\Omega$$, used for linear phase evolution.
    + [`phase`](/classes/transforms/wvtransformhydrostatic/phase.html) unit-magnitude phase factor that advances `Ap` from `t0` to `t`
    + [`conjPhase`](/classes/transforms/wvtransformhydrostatic/conjphase.html) conjugate phase factor that advances `Am` from `t0` to `t`
+ Create a related transform
  + [`boussinesqTransform`](/classes/transforms/wvtransformhydrostatic/boussinesqtransform.html) Create the corresponding nonhydrostatic Boussinesq transform.
  + [`spectralVariableWithResolution`](/classes/transforms/wvtransformhydrostatic/spectralvariablewithresolution.html) create a new variable with different resolution
  + [`waveVortexTransformWithDoubleResolution`](/classes/transforms/wvtransformhydrostatic/wavevortextransformwithdoubleresolution.html) create a new WVTransform with double resolution
  + [`waveVortexTransformWithExplicitAntialiasing`](/classes/transforms/wvtransformhydrostatic/wavevortextransformwithexplicitantialiasing.html) Create an explicit-antialiasing transform with the same grid.
  + [`waveVortexTransformWithResolution`](/classes/transforms/wvtransformhydrostatic/wavevortextransformwithresolution.html) Create the same transform family at a new resolution.
+ Extend a transform
  + Flow components
    + [`addFlowComponent`](/classes/transforms/wvtransformhydrostatic/addflowcomponent.html) add a flow component and its standard variables
    + [`addPrimaryFlowComponent`](/classes/transforms/wvtransformhydrostatic/addprimaryflowcomponent.html) add a primary flow component, automatically added to the flow
  + Operations and variables
    + [`addOperation`](/classes/transforms/wvtransformhydrostatic/addoperation.html) Register one or more operations and their output variables.
    + [`operationWithName`](/classes/transforms/wvtransformhydrostatic/operationwithname.html) retrieve a WVOperation by name
    + [`removeOperation`](/classes/transforms/wvtransformhydrostatic/removeoperation.html) Remove the exact registered operation and its cached outputs.
+ Get package information
  + [`version`](/classes/transforms/wvtransformhydrostatic/version.html) Installed WaveVortexModel version.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Projection and reconstruction coefficients
  + [`A0N`](/classes/transforms/wvtransformhydrostatic/a0n.html) These projection coefficients map the density-displacement state variable onto $$A_0$$. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 3 entries of $$S^{-1}$$ for the primary internal-gravity-wave and geostrophic solutions in equation C5.
  + [`A0U`](/classes/transforms/wvtransformhydrostatic/a0u.html) These projection coefficients map the $$u$$ state variable onto $$A_0$$. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 1 entries of $$S^{-1}$$ for the primary internal-gravity-wave and geostrophic solutions in equation C5.
  + [`A0V`](/classes/transforms/wvtransformhydrostatic/a0v.html) These projection coefficients map the $$v$$ state variable onto $$A_0$$. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 2 entries of $$S^{-1}$$ for the primary internal-gravity-wave and geostrophic solutions in equation C5.
  + [`A0Z`](/classes/transforms/wvtransformhydrostatic/a0z.html)
  + [`ApmD`](/classes/transforms/wvtransformhydrostatic/apmd.html)
  + [`ApmN`](/classes/transforms/wvtransformhydrostatic/apmn.html)
  + [`Feta`](/classes/transforms/wvtransformhydrostatic/feta.html)
  + [`Fu`](/classes/transforms/wvtransformhydrostatic/fu.html)
  + [`Fv`](/classes/transforms/wvtransformhydrostatic/fv.html)
  + [`NA0`](/classes/transforms/wvtransformhydrostatic/na0.html) These reconstruction coefficients map $$A_0$$ onto the density-displacement state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 3 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`NAm`](/classes/transforms/wvtransformhydrostatic/nam.html) These reconstruction coefficients map $$A_-$$ onto the density-displacement state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 2 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`NAp`](/classes/transforms/wvtransformhydrostatic/nap.html) These reconstruction coefficients map $$A_+$$ onto the density-displacement state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 1 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`P0`](/classes/transforms/wvtransformhydrostatic/p0.html) Preconditioner for F, size(P)=[Nj 1]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`PA0`](/classes/transforms/wvtransformhydrostatic/pa0.html)
  + [`Q0`](/classes/transforms/wvtransformhydrostatic/q0.html) Preconditioner for G, size(Q)=[Nj 1]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`UA0`](/classes/transforms/wvtransformhydrostatic/ua0.html) These reconstruction coefficients map $$A_0$$ onto the $$u$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 1, column 3 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`UAm`](/classes/transforms/wvtransformhydrostatic/uam.html) These reconstruction coefficients map $$A_-$$ onto the $$u$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 1, column 2 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`UAp`](/classes/transforms/wvtransformhydrostatic/uap.html) These reconstruction coefficients map $$A_+$$ onto the $$u$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 1, column 1 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`VA0`](/classes/transforms/wvtransformhydrostatic/va0.html) These reconstruction coefficients map $$A_0$$ onto the $$v$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 2, column 3 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`VAm`](/classes/transforms/wvtransformhydrostatic/vam.html) These reconstruction coefficients map $$A_-$$ onto the $$v$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 2, column 2 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`VAp`](/classes/transforms/wvtransformhydrostatic/vap.html) These reconstruction coefficients map $$A_+$$ onto the $$v$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 2, column 1 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`WAm`](/classes/transforms/wvtransformhydrostatic/wam.html) These reconstruction coefficients map $$A_-$$ onto the $$w$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 4, column 2 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
  + [`WAp`](/classes/transforms/wvtransformhydrostatic/wap.html) These reconstruction coefficients map $$A_+$$ onto the $$w$$ state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 4, column 1 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.
+ Geometry and mode indexing
  + [`conjugateDimension`](/classes/transforms/wvtransformhydrostatic/conjugatedimension.html) assumed conjugate dimension
  + [`dftConjugateIndex`](/classes/transforms/wvtransformhydrostatic/dftconjugateindex.html) legacy vertically replicated conjugate index
  + [`dftPrimaryIndex`](/classes/transforms/wvtransformhydrostatic/dftprimaryindex.html) legacy vertically replicated index into the active Fourier storage
  + [`indexFromKLModeNumber`](/classes/transforms/wvtransformhydrostatic/indexfromklmodenumber.html) return the linear index into k_wv and l_wv from a mode number
  + [`indexFromModeNumber`](/classes/transforms/wvtransformhydrostatic/indexfrommodenumber.html) return the linear index into a spectral matrix given (k,l,j)
  + [`indicesFromDFTGridToWVGrid`](/classes/transforms/wvtransformhydrostatic/indicesfromdftgridtowvgrid.html) indices to convert from DFT to WV grid
  + [`indicesFromWVGridToDFTGrid`](/classes/transforms/wvtransformhydrostatic/indicesfromwvgridtodftgrid.html) indices to convert from WV to DFT grid
  + [`indicesFromWVGridToFFTWGrid`](/classes/transforms/wvtransformhydrostatic/indicesfromwvgridtofftwgrid.html) indices to convert from WV to DFT grid
  + [`isValidConjugateKLModeNumber`](/classes/transforms/wvtransformhydrostatic/isvalidconjugateklmodenumber.html) return a boolean indicating whether (k,l) is a valid conjugate WV mode number
  + [`isValidConjugateModeNumber`](/classes/transforms/wvtransformhydrostatic/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid conjugate mode number
  + [`isValidKLModeNumber`](/classes/transforms/wvtransformhydrostatic/isvalidklmodenumber.html) return a boolean indicating whether (k,l) is a valid WV mode number
  + [`isValidModeNumber`](/classes/transforms/wvtransformhydrostatic/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
  + [`isValidPrimaryKLModeNumber`](/classes/transforms/wvtransformhydrostatic/isvalidprimaryklmodenumber.html) return a boolean indicating whether (k,l) is a valid primary (non-conjugate) WV mode number
  + [`isValidPrimaryModeNumber`](/classes/transforms/wvtransformhydrostatic/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid primary (non-conjugate) mode number
  + [`kMode_dft`](/classes/transforms/wvtransformhydrostatic/kmode_dft.html) k mode-number on the DFT grid
  + [`kMode_wv`](/classes/transforms/wvtransformhydrostatic/kmode_wv.html) k mode number on the WV grid
  + [`klModeNumberFromIndex`](/classes/transforms/wvtransformhydrostatic/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
  + [`lMode_dft`](/classes/transforms/wvtransformhydrostatic/lmode_dft.html) l mode-number on the DFT grid
  + [`lMode_wv`](/classes/transforms/wvtransformhydrostatic/lmode_wv.html) l mode number on the WV grid
  + [`maskForAliasedModes`](/classes/transforms/wvtransformhydrostatic/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
  + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformhydrostatic/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
  + [`maskForNyquistModes`](/classes/transforms/wvtransformhydrostatic/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
  + [`modeNumberFromIndex`](/classes/transforms/wvtransformhydrostatic/modenumberfromindex.html) Return mode numbers for spectral linear indices.
  + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformhydrostatic/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
  + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformhydrostatic/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
  + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformhydrostatic/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
  + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformhydrostatic/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
  + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
  + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
  + [`wvConjugateIndex`](/classes/transforms/wvtransformhydrostatic/wvconjugateindex.html) legacy vertically replicated WV conjugate index
+ Spectral transforms and operators
  + [`FMatrix`](/classes/transforms/wvtransformhydrostatic/fmatrix.html) transformation matrix $$F_g$$
  + [`FinvMatrix`](/classes/transforms/wvtransformhydrostatic/finvmatrix.html) transformation matrix $$F_g^{-1}$$
  + [`GMatrix`](/classes/transforms/wvtransformhydrostatic/gmatrix.html) transformation matrix $$G_g$$
  + [`GinvMatrix`](/classes/transforms/wvtransformhydrostatic/ginvmatrix.html) transformation matrix $$G_g^{-1}$$
  + [`PF0`](/classes/transforms/wvtransformhydrostatic/pf0.html) size(PF,PG)=[Nj x Nz]
  + [`PF0inv`](/classes/transforms/wvtransformhydrostatic/pf0inv.html) Transformation matrices
  + [`QG0`](/classes/transforms/wvtransformhydrostatic/qg0.html) Preconditioned G-mode forward transformation
  + [`QG0inv`](/classes/transforms/wvtransformhydrostatic/qg0inv.html) Preconditioned G-mode inverse transformation
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformhydrostatic/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformhydrostatic/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`fastTransform`](/classes/transforms/wvtransformhydrostatic/fasttransform.html) fast transform object
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformhydrostatic/transformfromspatialdomainwithfio.html)
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformhydrostatic/transformfromspatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainwithfourieratposition.html)
  + [`transformWithG_wg`](/classes/transforms/wvtransformhydrostatic/transformwithg_wg.html)
+ Nonlinear flux and forcing internals
  + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformhydrostatic/enstrophyfluxfromf0.html)
  + [`fluxAtTimeCellArray`](/classes/transforms/wvtransformhydrostatic/fluxattimecellarray.html) y0 is a 3x1 cell array
  + [`fluxForForcing`](/classes/transforms/wvtransformhydrostatic/fluxforforcing.html)
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformhydrostatic/qgpvfluxfromf0.html)
  + [`rk4FluxForForcing`](/classes/transforms/wvtransformhydrostatic/rk4fluxforforcing.html)
  + [`spatialFluxForForcingWithName`](/classes/transforms/wvtransformhydrostatic/spatialfluxforforcingwithname.html)
  + [`sumFluxDictionary`](/classes/transforms/wvtransformhydrostatic/sumfluxdictionary.html)
+ Persistence internals
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformhydrostatic/classrequiredpropertynames.html)
  + [`geometryFromGroup`](/classes/transforms/wvtransformhydrostatic/geometryfromgroup.html)
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformhydrostatic/namesofrequiredpropertiesforgeometry.html)
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformhydrostatic/namesofrequiredpropertiesforrotatingfplane.html)
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformhydrostatic/namesofrequiredpropertiesfortransform.html)
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformhydrostatic/namesoftransformvariables.html)
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformhydrostatic/newnonrequiredpropertynames.html)
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformhydrostatic/newrequiredpropertynames.html)
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformhydrostatic/requiredpropertiesforgeometryfromgroup.html)
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformhydrostatic/requiredpropertiesforrotatingfplanefromgroup.html)
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformhydrostatic/requiredpropertiesfortransformfromgroup.html)
  + [`transformFromGroup`](/classes/transforms/wvtransformhydrostatic/transformfromgroup.html)
+ Caches and registries
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformhydrostatic/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformhydrostatic/propertyannotationsforrotatingfplane.html)
+ Class internals
  + [`Nk_dft`](/classes/transforms/wvtransformhydrostatic/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
  + [`Nl_dft`](/classes/transforms/wvtransformhydrostatic/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
  + [`chebfunForZArray`](/classes/transforms/wvtransformhydrostatic/chebfunforzarray.html)
  + [`dftConjugateIndices2D`](/classes/transforms/wvtransformhydrostatic/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
  + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformhydrostatic/dftprimaryindices2d.html) index into the DFT grid of each WV mode
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformhydrostatic/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isHermitian`](/classes/transforms/wvtransformhydrostatic/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`k_dft`](/classes/transforms/wvtransformhydrostatic/k_dft.html) k wavenumber dimension on the DFT grid
  + [`kl`](/classes/transforms/wvtransformhydrostatic/kl.html) wavenumber dimension
  + [`l_dft`](/classes/transforms/wvtransformhydrostatic/l_dft.html) l wavenumber dimension on the DFT grid
  + [`maxFg`](/classes/transforms/wvtransformhydrostatic/maxfg.html)
  + [`maxFw`](/classes/transforms/wvtransformhydrostatic/maxfw.html)
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformhydrostatic/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`setConjugateToUnity`](/classes/transforms/wvtransformhydrostatic/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
  + [`shouldExcludeConjugates`](/classes/transforms/wvtransformhydrostatic/shouldexcludeconjugates.html) whether the WV grid excludes redundant Hermitian-conjugate wavenumbers
  + [`shouldExcludeNyquist`](/classes/transforms/wvtransformhydrostatic/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformhydrostatic/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformhydrostatic/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors


---