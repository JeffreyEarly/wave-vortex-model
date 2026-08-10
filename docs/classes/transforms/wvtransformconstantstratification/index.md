---
layout: default
title: WVTransformConstantStratification
has_children: false
has_toc: false
mathjax: true
parent: Transforms
grand_parent: Class documentation
nav_order: 4
---

#  WVTransformConstantStratification

Decompose constant-stratification flow into wave and geostrophic components.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransformConstantStratification < <a href="/classes/transforms/wvtransform/" title="WVTransform">WVTransform</a></code></pre></div></div>

## Overview

To initialize an instance of the WVTransformConstantStratification
class you must specify the domain size, the number of grid points,
and the constant buoyancy frequency.

```matlab
N0 = 3*2*pi/3600;
wvt = WVTransformConstantStratification([100e3,100e3,4000],[64,64,65],N0=N0,latitude=30);
wvtHydrostatic = WVTransformConstantStratification([100e3,100e3,4000],[64,64,65],N0=N0,latitude=30,isHydrostatic=true);
```

The transform state is stored in [`Ap`](/classes/transforms/wvtransform/ap.html),
[`Am`](/classes/transforms/wvtransform/am.html), and
[`A0`](/classes/transforms/wvtransform/a0.html). Their current-time
views are `Apt`, `Amt`, and `A0t`.




## Topics
+ Create and restore a transform
  + [`WVTransformConstantStratification`](/classes/transforms/wvtransformconstantstratification/wvtransformconstantstratification.html) Create a wave-vortex transform for constant stratification.
  + [`waveVortexTransformFromFile`](/classes/transforms/wvtransformconstantstratification/wavevortextransformfromfile.html) Restore a WVTransformConstantStratification instance from an existing file
+ Inspect the domain
  + Physical environment
    + Planetary rotation
      + [`beta`](/classes/transforms/wvtransformconstantstratification/beta.html) meridional gradient of the Coriolis parameter
      + [`f`](/classes/transforms/wvtransformconstantstratification/f.html) Coriolis parameter
      + [`inertialPeriod`](/classes/transforms/wvtransformconstantstratification/inertialperiod.html) inertial period
      + [`latitude`](/classes/transforms/wvtransformconstantstratification/latitude.html) central latitude of the simulation
      + [`planetaryRadius`](/classes/transforms/wvtransformconstantstratification/planetaryradius.html) radius of the planetary body
      + [`rotationRate`](/classes/transforms/wvtransformconstantstratification/rotationrate.html) rotation rate of the planetary body
    + Stratification and reference density
      + [`N0`](/classes/transforms/wvtransformconstantstratification/n0.html) buoyancy frequency of the no-motion density
      + [`N2`](/classes/transforms/wvtransformconstantstratification/n2.html) Buoyancy frequency squared sampled on the vertical grid.
      + [`N2Function`](/classes/transforms/wvtransformconstantstratification/n2function.html) Function returning buoyancy frequency squared at requested depths.
      + [`buoyancyPeriod`](/classes/transforms/wvtransformconstantstratification/buoyancyperiod.html)
      + [`dLnN2`](/classes/transforms/wvtransformconstantstratification/dlnn2.html) $$\partial_z \ln N^2$$, vertical derivative of the logarithm of squared buoyancy frequency
      + [`rho0`](/classes/transforms/wvtransformconstantstratification/rho0.html) Boussinesq reference density.
      + [`rhoFunction`](/classes/transforms/wvtransformconstantstratification/rhofunction.html) Function returning the no-motion density profile at requested depths.
      + [`shouldUseTrueNoMotionProfile`](/classes/transforms/wvtransformconstantstratification/shouldusetruenomotionprofile.html)
    + Gravity
      + [`g`](/classes/transforms/wvtransformconstantstratification/g.html) gravitational acceleration
  + Spatial grid
    + Coordinate axes
      + [`x`](/classes/transforms/wvtransformconstantstratification/x.html) dimension
      + [`y`](/classes/transforms/wvtransformconstantstratification/y.html) dimension
      + [`z`](/classes/transforms/wvtransformconstantstratification/z.html) Vertical coordinate axis.
    + Coordinate arrays
      + [`X`](/classes/transforms/wvtransformconstantstratification/x_.html) x-coordinate matrix
      + [`Y`](/classes/transforms/wvtransformconstantstratification/y_.html) y-coordinate matrix
      + [`Z`](/classes/transforms/wvtransformconstantstratification/z_.html) z-coordinate matrix
      + [`xyzGrid`](/classes/transforms/wvtransformconstantstratification/xyzgrid.html)
    + Domain dimensions
      + [`Lx`](/classes/transforms/wvtransformconstantstratification/lx.html) length of the x-dimension
      + [`Ly`](/classes/transforms/wvtransformconstantstratification/ly.html) length of the y-dimension
      + [`Lz`](/classes/transforms/wvtransformconstantstratification/lz.html) length of the z-dimension
    + Resolution and shape
      + [`Nx`](/classes/transforms/wvtransformconstantstratification/nx.html) number of grid points in the x-dimension
      + [`Ny`](/classes/transforms/wvtransformconstantstratification/ny.html) number of grid points in the y-dimension
      + [`Nz`](/classes/transforms/wvtransformconstantstratification/nz.html) points in the third, untransformed, dimension
      + [`spatialMatrixSize`](/classes/transforms/wvtransformconstantstratification/spatialmatrixsize.html)
    + Quadrature and integration
      + [`z_int`](/classes/transforms/wvtransformconstantstratification/z_int.html) Vertical quadrature weights.
  + Spectral grid
    + Axes and spacing
      + [`kAxis`](/classes/transforms/wvtransformconstantstratification/kaxis.html) k coordinate
      + [`lAxis`](/classes/transforms/wvtransformconstantstratification/laxis.html) l coordinate
      + [`j`](/classes/transforms/wvtransformconstantstratification/j.html) Vertical-mode index axis.
      + [`dk`](/classes/transforms/wvtransformconstantstratification/dk.html) wavenumber spacing of the $$k$$ axis
      + [`dl`](/classes/transforms/wvtransformconstantstratification/dl.html) wavenumber spacing of the $$l$$ axis
    + Coordinate arrays
      + [`k`](/classes/transforms/wvtransformconstantstratification/k.html) wavenumber dimension on the WV grid
      + [`l`](/classes/transforms/wvtransformconstantstratification/l.html) wavenumber dimension on the WV grid
      + [`K`](/classes/transforms/wvtransformconstantstratification/k_.html) k-coordinate matrix
      + [`L`](/classes/transforms/wvtransformconstantstratification/l_.html) l-coordinate matrix
      + [`J`](/classes/transforms/wvtransformconstantstratification/j_.html) vertical mode-number matrix
      + [`kljGrid`](/classes/transforms/wvtransformconstantstratification/kljgrid.html)
    + Horizontal wavenumber geometry
      + [`Kh`](/classes/transforms/wvtransformconstantstratification/kh.html) horizontal wavenumber, $$Kh=\sqrt(K^2+L^2)$$
      + [`K2`](/classes/transforms/wvtransformconstantstratification/k2.html) squared horizontal wavenumber, $$K2=K^2+L^2$$
    + Resolution and shape
      + [`Nj`](/classes/transforms/wvtransformconstantstratification/nj.html) points in the j-coordinate, `length(z)`
      + [`Nkl`](/classes/transforms/wvtransformconstantstratification/nkl.html) length of the combined kl-wavenumber dimension on the WV grid
      + [`spectralMatrixSize`](/classes/transforms/wvtransformconstantstratification/spectralmatrixsize.html)
      + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformconstantstratification/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
      + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformconstantstratification/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
      + [`effectiveJMax`](/classes/transforms/wvtransformconstantstratification/effectivejmax.html)
    + Vertical modes and scaling
      + [`verticalModes`](/classes/transforms/wvtransformconstantstratification/verticalmodes.html) Vertical eigenmodes used by the transform.
      + [`h_0`](/classes/transforms/wvtransformconstantstratification/h_0.html) equivalent depth of each geostrophic mode
      + [`h_pm`](/classes/transforms/wvtransformconstantstratification/h_pm.html) equivalent depth of each wave mode
      + [`Lr2`](/classes/transforms/wvtransformconstantstratification/lr2.html) squared Rossby deformation radius of each geostrophic mode
      + [`waveModeVerticalStructureAtIndex`](/classes/transforms/wvtransformconstantstratification/wavemodeverticalstructureatindex.html) Return wave vertical-structure factors at one vertical grid index.
  + Transform configuration
    + [`isHydrostatic`](/classes/transforms/wvtransformconstantstratification/ishydrostatic.html) whether the transforms are hydrostatic or non-hydrostatic
    + [`shouldAntialias`](/classes/transforms/wvtransformconstantstratification/shouldantialias.html) whether quadratic antialiasing is enabled
+ Initialize the flow
  + General initialization
    + [`addRandomFlow`](/classes/transforms/wvtransformconstantstratification/addrandomflow.html) add randomized flow to the existing state
    + [`addUVEta`](/classes/transforms/wvtransformconstantstratification/adduveta.html) add $$(u,v,\eta)$$ to the existing values
    + [`initFromNetCDFFile`](/classes/transforms/wvtransformconstantstratification/initfromnetcdffile.html) initialize the flow from a NetCDF file
    + [`initWithRandomFlow`](/classes/transforms/wvtransformconstantstratification/initwithrandomflow.html) initialize with a random flow state
    + [`initWithUVEta`](/classes/transforms/wvtransformconstantstratification/initwithuveta.html) initialize with fluid variables $$(u,v,\eta)$$
    + [`initWithUVRho`](/classes/transforms/wvtransformconstantstratification/initwithuvrho.html) initialize with fluid variables $$(u,v,\rho)$$
    + [`removeAll`](/classes/transforms/wvtransformconstantstratification/removeall.html) removes all energy from the model
  + Waves
    + Individual modes
      + [`addWaveModes`](/classes/transforms/wvtransformconstantstratification/addwavemodes.html) add amplitudes of the given wave modes
      + [`initWithWaveModes`](/classes/transforms/wvtransformconstantstratification/initwithwavemodes.html) initialize with the given wave modes
      + [`removeAllWaves`](/classes/transforms/wvtransformconstantstratification/removeallwaves.html) removes all wave from the model, including inertial oscillations
      + [`setWaveModes`](/classes/transforms/wvtransformconstantstratification/setwavemodes.html) set amplitudes of the given wave modes
    + Wave spectra
      + [`addGMSpectrum`](/classes/transforms/wvtransformconstantstratification/addgmspectrum.html) add waves following a Garrett-Munk spectrum
      + [`addWavesWithFrequencySpectrum`](/classes/transforms/wvtransformconstantstratification/addwaveswithfrequencyspectrum.html) add waves with a specified frequency spectrum
      + [`initWavesWithFrequencySpectrum`](/classes/transforms/wvtransformconstantstratification/initwaveswithfrequencyspectrum.html) initialize with waves of a specified frequency spectrum
      + [`initWithAlternativeSpectrum`](/classes/transforms/wvtransformconstantstratification/initwithalternativespectrum.html) initialize with an alternative formulation of the GM spectrum in the wavenumber domain.
      + [`initWithGMSpectrum`](/classes/transforms/wvtransformconstantstratification/initwithgmspectrum.html) initialize the wave field following a Garrett-Munk spectrum
  + Inertial oscillations
    + [`addInertialMotions`](/classes/transforms/wvtransformconstantstratification/addinertialmotions.html) add inertial motions to existing inertial motions
    + [`initWithInertialMotions`](/classes/transforms/wvtransformconstantstratification/initwithinertialmotions.html) initialize with inertial motions
    + [`removeAllInertialMotions`](/classes/transforms/wvtransformconstantstratification/removeallinertialmotions.html) remove all inertial motions
    + [`setInertialMotions`](/classes/transforms/wvtransformconstantstratification/setinertialmotions.html) set inertial motions
  + Geostrophic motions
    + [`initWithGeostrophicStreamfunction`](/classes/transforms/wvtransformconstantstratification/initwithgeostrophicstreamfunction.html) initialize with a geostrophic streamfunction
    + [`setGeostrophicStreamfunction`](/classes/transforms/wvtransformconstantstratification/setgeostrophicstreamfunction.html) set a geostrophic streamfunction
    + [`addGeostrophicStreamfunction`](/classes/transforms/wvtransformconstantstratification/addgeostrophicstreamfunction.html) add a geostrophic streamfunction to existing geostrophic motions
    + [`setGeostrophicModes`](/classes/transforms/wvtransformconstantstratification/setgeostrophicmodes.html) set amplitudes of the given geostrophic modes
    + [`addGeostrophicModes`](/classes/transforms/wvtransformconstantstratification/addgeostrophicmodes.html) add amplitudes of the given geostrophic modes
    + [`removeAllGeostrophicMotions`](/classes/transforms/wvtransformconstantstratification/removeallgeostrophicmotions.html) remove all geostrophic motions
  + Mean density anomalies
    + [`addMeanDensityAnomaly`](/classes/transforms/wvtransformconstantstratification/addmeandensityanomaly.html) Add a mean-density anomaly to the existing fluid state.
    + [`initWithMeanDensityAnomaly`](/classes/transforms/wvtransformconstantstratification/initwithmeandensityanomaly.html) Initialize the fluid state with a mean-density anomaly.
    + [`removeAllMeanDensityAnomaly`](/classes/transforms/wvtransformconstantstratification/removeallmeandensityanomaly.html) remove all mean density anomalies
    + [`setMeanDensityAnomaly`](/classes/transforms/wvtransformconstantstratification/setmeandensityanomaly.html) Set the mean-density-anomaly component.
+ Evaluate physical fields
  + Registered variables
    + [`hasVariableWithName`](/classes/transforms/wvtransformconstantstratification/hasvariablewithname.html) Test whether state variables are registered by name.
    + [`summarizeVariables`](/classes/transforms/wvtransformconstantstratification/summarizevariables.html) Print a table of registered state variables and cache status.
    + [`variableNames`](/classes/transforms/wvtransformconstantstratification/variablenames.html) Return the names of all registered state variables.
    + [`variableWithName`](/classes/transforms/wvtransformconstantstratification/variablewithname.html) Compute or retrieve one or more registered transform variables.
  + On the model grid
    + Velocity
      + [`u`](/classes/transforms/wvtransformconstantstratification/u.html) x-component of the fluid velocity
      + [`v`](/classes/transforms/wvtransformconstantstratification/v.html) y-component of the fluid velocity
      + [`w`](/classes/transforms/wvtransformconstantstratification/w.html) z-component of the fluid velocity
    + Density and displacement
      + [`eta`](/classes/transforms/wvtransformconstantstratification/eta.html) approximate isopycnal deviation
      + [`rho_e`](/classes/transforms/wvtransformconstantstratification/rho_e.html) excess density
      + [`rho_nm`](/classes/transforms/wvtransformconstantstratification/rho_nm.html) no-motion density profile
      + [`rho_nm0`](/classes/transforms/wvtransformconstantstratification/rho_nm0.html) No-motion density profile sampled on the vertical grid.
      + [`rho_total`](/classes/transforms/wvtransformconstantstratification/rho_total.html) total potential density
    + Pressure and surface fields
      + [`p`](/classes/transforms/wvtransformconstantstratification/p.html) pressure anomaly
      + [`pi`](/classes/transforms/wvtransformconstantstratification/pi.html) height anomaly
      + [`ssh`](/classes/transforms/wvtransformconstantstratification/ssh.html) sea-surface height
      + [`ssu`](/classes/transforms/wvtransformconstantstratification/ssu.html) x-component of the fluid velocity at the surface
      + [`ssv`](/classes/transforms/wvtransformconstantstratification/ssv.html) y-component of the fluid velocity at the surface
    + Vorticity and geostrophic fields
      + [`psi`](/classes/transforms/wvtransformconstantstratification/psi.html) geostrophic streamfunction
      + [`qgpv`](/classes/transforms/wvtransformconstantstratification/qgpv.html) quasigeostrophic potential vorticity
      + [`zeta_x`](/classes/transforms/wvtransformconstantstratification/zeta_x.html) x-component component of relative vorticity
      + [`zeta_y`](/classes/transforms/wvtransformconstantstratification/zeta_y.html) y-component component of relative vorticity
      + [`zeta_z`](/classes/transforms/wvtransformconstantstratification/zeta_z.html) vertical component of relative vorticity
  + At arbitrary positions
    + [`variableAtPositionWithName`](/classes/transforms/wvtransformconstantstratification/variableatpositionwithname.html) Access dynamical variables at arbitrary positions in the domain.
  + Isopycnal utilities
    + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformconstantstratification/placeparticlesonisopycnal.html) Return particle depths on the isopycnal identified by a no-motion depth.
+ Manage forcing and closures
  + [`addForcing`](/classes/transforms/wvtransformconstantstratification/addforcing.html) Add forcing or closure objects to this transform.
  + [`forcing`](/classes/transforms/wvtransformconstantstratification/forcing.html) array of WVForcing objects
  + [`forcingNames`](/classes/transforms/wvtransformconstantstratification/forcingnames.html) retrieve the names of all available variables. This preserves
  + [`forcingWithName`](/classes/transforms/wvtransformconstantstratification/forcingwithname.html) Return registered forcing objects by name.
  + [`hasClosure`](/classes/transforms/wvtransformconstantstratification/hasclosure.html)
  + [`hasForcingWithName`](/classes/transforms/wvtransformconstantstratification/hasforcingwithname.html) Test whether forcing objects are registered by name.
  + [`removeAllForcing`](/classes/transforms/wvtransformconstantstratification/removeallforcing.html) Remove every forcing and closure from this transform.
  + [`removeForcing`](/classes/transforms/wvtransformconstantstratification/removeforcing.html) Remove the exact registered forcing objects.
  + [`setForcing`](/classes/transforms/wvtransformconstantstratification/setforcing.html) Replace the complete forcing registry.
  + [`summarizeForcing`](/classes/transforms/wvtransformconstantstratification/summarizeforcing.html) Print a table of registered forcing and closure objects.
+ Analyze the flow
  + Energy and summaries
    + [`inertialEnergy`](/classes/transforms/wvtransformconstantstratification/inertialenergy.html) total energy of the inertial flow
    + [`mdaEnergy`](/classes/transforms/wvtransformconstantstratification/mdaenergy.html) total energy of the mean density anomaly
    + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformconstantstratification/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
    + [`waveEnergy`](/classes/transforms/wvtransformconstantstratification/waveenergy.html) Total energy of the internal-gravity-wave flow.
    + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformconstantstratification/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
    + [`geostrophicEnergy`](/classes/transforms/wvtransformconstantstratification/geostrophicenergy.html) total energy, geostrophic
    + [`hasMeanPressureDifference`](/classes/transforms/wvtransformconstantstratification/hasmeanpressuredifference.html) Diagnose an MDA mean-pressure difference between the boundaries.
    + [`summarizeDegreesOfFreedom`](/classes/transforms/wvtransformconstantstratification/summarizedegreesoffreedom.html) Summarize the spatial grid and active spectral degrees of freedom.
    + [`summarizeEnergyContent`](/classes/transforms/wvtransformconstantstratification/summarizeenergycontent.html) displays a summary of the energy content of the fluid
    + [`summarizeModeEnergy`](/classes/transforms/wvtransformconstantstratification/summarizemodeenergy.html) List the most energetic modes
    + [`totalEnergy`](/classes/transforms/wvtransformconstantstratification/totalenergy.html) horizontally-averaged depth-integrated energy computed spectrally from wave-vortex coefficients
    + [`totalEnergyOfFlowComponent`](/classes/transforms/wvtransformconstantstratification/totalenergyofflowcomponent.html)
    + [`totalEnergySpatiallyIntegrated`](/classes/transforms/wvtransformconstantstratification/totalenergyspatiallyintegrated.html) horizontally-averaged depth-integrated energy computed in the spatial domain
  + Flow diagnostics
    + [`uvMax`](/classes/transforms/wvtransformconstantstratification/uvmax.html) max horizontal fluid speed
    + [`wMax`](/classes/transforms/wvtransformconstantstratification/wmax.html) max vertical fluid speed
  + Density validity
    + [`isDensityInValidRange`](/classes/transforms/wvtransformconstantstratification/isdensityinvalidrange.html) Test whether total density remains within the no-motion density range.
  + Potential vorticity and enstrophy
    + [`totalEnstrophy`](/classes/transforms/wvtransformconstantstratification/totalenstrophy.html)
    + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformconstantstratification/totalenstrophyspatiallyintegrated.html)
  + Spectra
    + Spectral fields
      + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformconstantstratification/crossspectrumwithfgtransform.html)
      + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformconstantstratification/crossspectrumwithggtransform.html)
      + [`spectrumWithFgTransform`](/classes/transforms/wvtransformconstantstratification/spectrumwithfgtransform.html)
      + [`spectrumWithGgTransform`](/classes/transforms/wvtransformconstantstratification/spectrumwithggtransform.html)
      + [`transformToKLAxes`](/classes/transforms/wvtransformconstantstratification/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
    + Radial wavenumber
      + [`kRadial`](/classes/transforms/wvtransformconstantstratification/kradial.html) radial (k,l) wavenumber on the WV grid
      + [`transformToRadialWavenumber`](/classes/transforms/wvtransformconstantstratification/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
    + Frequency
      + [`convertFromWavenumberToFrequency`](/classes/transforms/wvtransformconstantstratification/convertfromwavenumbertofrequency.html) Bin wave energy by vertical mode and intrinsic frequency
+ Save transform state
  + [`writeToFile`](/classes/transforms/wvtransformconstantstratification/writetofile.html) Write this instance to NetCDF file.
+ Convert representations
  + Physical fields and coefficients
    + [`transformUVEtaToWaveVortex`](/classes/transforms/wvtransformconstantstratification/transformuvetatowavevortex.html) transform fluid variables $$(u,v,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
    + [`transformUVWEtaToWaveVortex`](/classes/transforms/wvtransformconstantstratification/transformuvwetatowavevortex.html) transform momentum variables $$(u,v,w,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
    + [`transformWaveVortexToUVWEta`](/classes/transforms/wvtransformconstantstratification/transformwavevortextouvweta.html) transform wave-vortex coefficients $$(A_+,A_-,A_0)$$ to fluid variables $$(u,v,\eta)$$.
+ Differentiate and integrate fields
  + [`diffX`](/classes/transforms/wvtransformconstantstratification/diffx.html)
  + [`diffY`](/classes/transforms/wvtransformconstantstratification/diffy.html)
  + [`diffZF`](/classes/transforms/wvtransformconstantstratification/diffzf.html) Differentiate an F-grid field with respect to z.
  + [`diffZG`](/classes/transforms/wvtransformconstantstratification/diffzg.html) Differentiate a G-grid field with respect to z.
  + [`intZF`](/classes/transforms/wvtransformconstantstratification/intzf.html) Return the first antiderivative of an F-representation.
  + [`intZG`](/classes/transforms/wvtransformconstantstratification/intzg.html) Return the bottom-zero first antiderivative of a G-representation.
+ Inspect flow components
  + [`geostrophicComponent`](/classes/transforms/wvtransformconstantstratification/geostrophiccomponent.html) returns the geostrophic flow component
  + [`waveComponent`](/classes/transforms/wvtransformconstantstratification/wavecomponent.html) returns the internal gravity wave flow component
  + [`inertialComponent`](/classes/transforms/wvtransformconstantstratification/inertialcomponent.html) returns the inertial oscillation flow component
  + [`mdaComponent`](/classes/transforms/wvtransformconstantstratification/mdacomponent.html) returns the mean density anomaly component
  + [`flowComponentNames`](/classes/transforms/wvtransformconstantstratification/flowcomponentnames.html) retrieve the names of all available variables
  + [`flowComponentWithName`](/classes/transforms/wvtransformconstantstratification/flowcomponentwithname.html) retrieve a WVFlowComponent by name
  + [`flowComponents`](/classes/transforms/wvtransformconstantstratification/flowcomponents.html)
  + [`primaryFlowComponentNames`](/classes/transforms/wvtransformconstantstratification/primaryflowcomponentnames.html) retrieve the names of all available variables
  + [`primaryFlowComponentWithName`](/classes/transforms/wvtransformconstantstratification/primaryflowcomponentwithname.html) retrieve a WVPrimaryFlowComponent by name
  + [`primaryFlowComponents`](/classes/transforms/wvtransformconstantstratification/primaryflowcomponents.html)
  + [`summarizeFlowComponents`](/classes/transforms/wvtransformconstantstratification/summarizeflowcomponents.html) Print a table of registered primary and diagnostic components.
  + [`totalFlowComponent`](/classes/transforms/wvtransformconstantstratification/totalflowcomponent.html)
+ Inspect wave-vortex coefficients
  + Stored coefficients
    + [`Ap`](/classes/transforms/wvtransformconstantstratification/ap.html) Positive-frequency wave and inertial coefficients at reference time `t0`.
    + [`Am`](/classes/transforms/wvtransformconstantstratification/am.html) Negative-frequency wave and inertial coefficients at reference time `t0`.
    + [`A0`](/classes/transforms/wvtransformconstantstratification/a0.html) Zero-frequency geostrophic and mean-density-anomaly coefficients.
  + Coefficients at the current time
    + [`Apt`](/classes/transforms/wvtransformconstantstratification/apt.html) positive-frequency coefficients at current time t
    + [`Amt`](/classes/transforms/wvtransformconstantstratification/amt.html) negative-frequency coefficients at current time t
    + [`A0t`](/classes/transforms/wvtransformconstantstratification/a0t.html) zero-frequency coefficients at current time t
    + [`waveCoefficientsAtTimeT`](/classes/transforms/wvtransformconstantstratification/wavecoefficientsattimet.html)
  + Coefficient evolution
    + [`t0`](/classes/transforms/wvtransformconstantstratification/t0.html) Reference time for the stored wave phases, in seconds.
    + [`t`](/classes/transforms/wvtransformconstantstratification/t.html) Current transform time in seconds.
    + [`Omega`](/classes/transforms/wvtransformconstantstratification/omega.html) Intrinsic angular frequency of each wave and inertial mode.
    + [`iOmega`](/classes/transforms/wvtransformconstantstratification/iomega.html) Imaginary angular frequency, $$i\Omega$$, used for linear phase evolution.
    + [`phase`](/classes/transforms/wvtransformconstantstratification/phase.html) unit-magnitude phase factor that advances `Ap` from `t0` to `t`
    + [`conjPhase`](/classes/transforms/wvtransformconstantstratification/conjphase.html) conjugate phase factor that advances `Am` from `t0` to `t`
+ Create a related transform
  + [`spectralVariableWithResolution`](/classes/transforms/wvtransformconstantstratification/spectralvariablewithresolution.html) create a new variable with different resolution
  + [`waveVortexTransformWithDoubleResolution`](/classes/transforms/wvtransformconstantstratification/wavevortextransformwithdoubleresolution.html) create a new WVTransform with double resolution
  + [`waveVortexTransformWithExplicitAntialiasing`](/classes/transforms/wvtransformconstantstratification/wavevortextransformwithexplicitantialiasing.html)
  + [`waveVortexTransformWithResolution`](/classes/transforms/wvtransformconstantstratification/wavevortextransformwithresolution.html) Construct the same transform family at a requested resolution.
+ Extend a transform
  + Flow components
    + [`addFlowComponent`](/classes/transforms/wvtransformconstantstratification/addflowcomponent.html) add a flow component and its standard variables
    + [`addPrimaryFlowComponent`](/classes/transforms/wvtransformconstantstratification/addprimaryflowcomponent.html) add a primary flow component, automatically added to the flow
  + Operations and variables
    + [`addOperation`](/classes/transforms/wvtransformconstantstratification/addoperation.html) Register one or more operations and their output variables.
    + [`operationWithName`](/classes/transforms/wvtransformconstantstratification/operationwithname.html) retrieve a WVOperation by name
    + [`removeOperation`](/classes/transforms/wvtransformconstantstratification/removeoperation.html) Remove the exact registered operation and its cached outputs.
+ Get package information
  + [`version`](/classes/transforms/wvtransformconstantstratification/version.html) Installed WaveVortexModel version.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Projection and reconstruction coefficients
  + [`A0N`](/classes/transforms/wvtransformconstantstratification/a0n.html) matrix component that multiplies $$\tilde{\eta}$$ to compute $$A_0$$.
  + [`A0U`](/classes/transforms/wvtransformconstantstratification/a0u.html) matrix component that multiplies $$\tilde{u}$$ to compute $$A_0$$.
  + [`A0V`](/classes/transforms/wvtransformconstantstratification/a0v.html) matrix component that multiplies $$\tilde{v}$$ to compute $$A_0$$.
  + [`A0Z`](/classes/transforms/wvtransformconstantstratification/a0z.html)
  + [`ApmD`](/classes/transforms/wvtransformconstantstratification/apmd.html)
  + [`ApmD_scaled`](/classes/transforms/wvtransformconstantstratification/apmd_scaled.html)
  + [`ApmN`](/classes/transforms/wvtransformconstantstratification/apmn.html)
  + [`ApmW_scaled`](/classes/transforms/wvtransformconstantstratification/apmw_scaled.html)
  + [`Feta`](/classes/transforms/wvtransformconstantstratification/feta.html)
  + [`Fu`](/classes/transforms/wvtransformconstantstratification/fu.html)
  + [`Fv`](/classes/transforms/wvtransformconstantstratification/fv.html)
  + [`NA0`](/classes/transforms/wvtransformconstantstratification/na0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{\eta}$$.
  + [`NAm`](/classes/transforms/wvtransformconstantstratification/nam.html)
  + [`NAp`](/classes/transforms/wvtransformconstantstratification/nap.html)
  + [`PA0`](/classes/transforms/wvtransformconstantstratification/pa0.html)
  + [`UA0`](/classes/transforms/wvtransformconstantstratification/ua0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{u}$$.
  + [`UAm`](/classes/transforms/wvtransformconstantstratification/uam.html)
  + [`UAp`](/classes/transforms/wvtransformconstantstratification/uap.html)
  + [`VA0`](/classes/transforms/wvtransformconstantstratification/va0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{v}$$.
  + [`VAm`](/classes/transforms/wvtransformconstantstratification/vam.html)
  + [`VAp`](/classes/transforms/wvtransformconstantstratification/vap.html)
  + [`WAm`](/classes/transforms/wvtransformconstantstratification/wam.html)
  + [`WAp`](/classes/transforms/wvtransformconstantstratification/wap.html)
+ Geometry and mode indexing
  + [`buildVerticalModeProjectionOperators`](/classes/transforms/wvtransformconstantstratification/buildverticalmodeprojectionoperators.html) Build the transformation matrices
  + [`conjugateDimension`](/classes/transforms/wvtransformconstantstratification/conjugatedimension.html) assumed conjugate dimension
  + [`dftConjugateIndex`](/classes/transforms/wvtransformconstantstratification/dftconjugateindex.html) legacy vertically replicated conjugate index
  + [`dftPrimaryIndex`](/classes/transforms/wvtransformconstantstratification/dftprimaryindex.html) legacy vertically replicated index into the active Fourier storage
  + [`indexFromKLModeNumber`](/classes/transforms/wvtransformconstantstratification/indexfromklmodenumber.html) return the linear index into k_wv and l_wv from a mode number
  + [`indexFromModeNumber`](/classes/transforms/wvtransformconstantstratification/indexfrommodenumber.html) return the linear index into a spectral matrix given (k,l,j)
  + [`indicesFromDFTGridToWVGrid`](/classes/transforms/wvtransformconstantstratification/indicesfromdftgridtowvgrid.html) indices to convert from DFT to WV grid
  + [`indicesFromWVGridToDFTGrid`](/classes/transforms/wvtransformconstantstratification/indicesfromwvgridtodftgrid.html) indices to convert from WV to DFT grid
  + [`indicesFromWVGridToFFTWGrid`](/classes/transforms/wvtransformconstantstratification/indicesfromwvgridtofftwgrid.html) indices to convert from WV to DFT grid
  + [`isValidConjugateKLModeNumber`](/classes/transforms/wvtransformconstantstratification/isvalidconjugateklmodenumber.html) return a boolean indicating whether (k,l) is a valid conjugate WV mode number
  + [`isValidConjugateModeNumber`](/classes/transforms/wvtransformconstantstratification/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid conjugate mode number
  + [`isValidKLModeNumber`](/classes/transforms/wvtransformconstantstratification/isvalidklmodenumber.html) return a boolean indicating whether (k,l) is a valid WV mode number
  + [`isValidModeNumber`](/classes/transforms/wvtransformconstantstratification/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
  + [`isValidPrimaryKLModeNumber`](/classes/transforms/wvtransformconstantstratification/isvalidprimaryklmodenumber.html) return a boolean indicating whether (k,l) is a valid primary (non-conjugate) WV mode number
  + [`isValidPrimaryModeNumber`](/classes/transforms/wvtransformconstantstratification/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid primary (non-conjugate) mode number
  + [`kMode_dft`](/classes/transforms/wvtransformconstantstratification/kmode_dft.html) k mode-number on the DFT grid
  + [`kMode_wv`](/classes/transforms/wvtransformconstantstratification/kmode_wv.html) k mode number on the WV grid
  + [`klModeNumberFromIndex`](/classes/transforms/wvtransformconstantstratification/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
  + [`lMode_dft`](/classes/transforms/wvtransformconstantstratification/lmode_dft.html) l mode-number on the DFT grid
  + [`lMode_wv`](/classes/transforms/wvtransformconstantstratification/lmode_wv.html) l mode number on the WV grid
  + [`maskForAliasedModes`](/classes/transforms/wvtransformconstantstratification/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
  + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformconstantstratification/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
  + [`maskForNyquistModes`](/classes/transforms/wvtransformconstantstratification/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
  + [`modeNumberFromIndex`](/classes/transforms/wvtransformconstantstratification/modenumberfromindex.html) Return mode numbers for spectral linear indices.
  + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformconstantstratification/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
  + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformconstantstratification/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
  + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformconstantstratification/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
  + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformconstantstratification/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
  + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformconstantstratification/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
  + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformconstantstratification/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
  + [`wvConjugateIndex`](/classes/transforms/wvtransformconstantstratification/wvconjugateindex.html) legacy vertically replicated WV conjugate index
+ Spectral transforms and operators
  + [`CosineTransformBackMatrix`](/classes/transforms/wvtransformconstantstratification/cosinetransformbackmatrix.html) Discrete Cosine Transform (DCT-I) matrix
  + [`CosineTransformForwardMatrix`](/classes/transforms/wvtransformconstantstratification/cosinetransformforwardmatrix.html) Discrete Cosine Transform (DCT-I) matrix
  + [`DCT`](/classes/transforms/wvtransformconstantstratification/dct.html)
  + [`DST`](/classes/transforms/wvtransformconstantstratification/dst.html)
  + [`FMatrix`](/classes/transforms/wvtransformconstantstratification/fmatrix.html) transformation matrix $$F_g$$
  + [`FinvMatrix`](/classes/transforms/wvtransformconstantstratification/finvmatrix.html) transformation matrix $$F_g^{-1}$$
  + [`FwInvMatrix`](/classes/transforms/wvtransformconstantstratification/fwinvmatrix.html) transformation matrix $$F_w^{-1}$$
  + [`FwMatrix`](/classes/transforms/wvtransformconstantstratification/fwmatrix.html) transformation matrix $$F_w$$
  + [`GMatrix`](/classes/transforms/wvtransformconstantstratification/gmatrix.html) transformation matrix $$G_g$$
  + [`GinvMatrix`](/classes/transforms/wvtransformconstantstratification/ginvmatrix.html) transformation matrix $$G_g^{-1}$$
  + [`GwInvMatrix`](/classes/transforms/wvtransformconstantstratification/gwinvmatrix.html) transformation matrix $$G_w^{-1}$$
  + [`GwMatrix`](/classes/transforms/wvtransformconstantstratification/gwmatrix.html) transformation matrix $$G_w$$
  + [`SineTransformBackMatrix`](/classes/transforms/wvtransformconstantstratification/sinetransformbackmatrix.html) CosineTransformBackMatrix  Discrete Cosine Transform (DCT-I) matrix
  + [`SineTransformForwardMatrix`](/classes/transforms/wvtransformconstantstratification/sinetransformforwardmatrix.html) CosineTransformForwardMatrix  Discrete Cosine Transform (DCT-I) matrix
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformconstantstratification/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformconstantstratification/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`fastTransform`](/classes/transforms/wvtransformconstantstratification/fasttransform.html) fast transform object
  + [`iDCT`](/classes/transforms/wvtransformconstantstratification/idct.html)
  + [`iDST`](/classes/transforms/wvtransformconstantstratification/idst.html)
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformconstantstratification/transformfromspatialdomainwithfio.html)
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformconstantstratification/transformfromspatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformconstantstratification/transformtospatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformconstantstratification/transformtospatialdomainwithfourieratposition.html)
  + [`transformWithG_wg`](/classes/transforms/wvtransformconstantstratification/transformwithg_wg.html)
+ Nonlinear flux and forcing internals
  + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformconstantstratification/enstrophyfluxfromf0.html)
  + [`fluxForForcing`](/classes/transforms/wvtransformconstantstratification/fluxforforcing.html)
  + [`nonlinearFluxFunction`](/classes/transforms/wvtransformconstantstratification/nonlinearfluxfunction.html)
  + [`nonlinearFluxHydrostatic`](/classes/transforms/wvtransformconstantstratification/nonlinearfluxhydrostatic.html)
  + [`nonlinearFluxNonhydrostatic`](/classes/transforms/wvtransformconstantstratification/nonlinearfluxnonhydrostatic.html)
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformconstantstratification/qgpvfluxfromf0.html)
  + [`spatialFluxForForcingWithName`](/classes/transforms/wvtransformconstantstratification/spatialfluxforforcingwithname.html)
+ Persistence internals
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformconstantstratification/classrequiredpropertynames.html)
  + [`geometryFromGroup`](/classes/transforms/wvtransformconstantstratification/geometryfromgroup.html)
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformconstantstratification/namesofrequiredpropertiesforgeometry.html)
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformconstantstratification/namesofrequiredpropertiesforrotatingfplane.html)
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformconstantstratification/namesofrequiredpropertiesfortransform.html)
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformconstantstratification/namesoftransformvariables.html)
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformconstantstratification/newnonrequiredpropertynames.html)
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformconstantstratification/newrequiredpropertynames.html)
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformconstantstratification/requiredpropertiesforgeometryfromgroup.html)
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformconstantstratification/requiredpropertiesforrotatingfplanefromgroup.html)
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformconstantstratification/requiredpropertiesfortransformfromgroup.html)
  + [`transformFromGroup`](/classes/transforms/wvtransformconstantstratification/transformfromgroup.html)
+ Caches and registries
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformconstantstratification/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformconstantstratification/propertyannotationsforrotatingfplane.html)
+ Class internals
  + [`F_g`](/classes/transforms/wvtransformconstantstratification/f_g.html)
  + [`F_wg`](/classes/transforms/wvtransformconstantstratification/f_wg.html)
  + [`G_g`](/classes/transforms/wvtransformconstantstratification/g_g.html)
  + [`G_wg`](/classes/transforms/wvtransformconstantstratification/g_wg.html)
  + [`Nk_dft`](/classes/transforms/wvtransformconstantstratification/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
  + [`Nl_dft`](/classes/transforms/wvtransformconstantstratification/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
  + [`chebfunForZArray`](/classes/transforms/wvtransformconstantstratification/chebfunforzarray.html)
  + [`cos_alpha`](/classes/transforms/wvtransformconstantstratification/cos_alpha.html)
  + [`dftConjugateIndices2D`](/classes/transforms/wvtransformconstantstratification/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
  + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformconstantstratification/dftprimaryindices2d.html) index into the DFT grid of each WV mode
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformconstantstratification/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isHermitian`](/classes/transforms/wvtransformconstantstratification/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`k_dft`](/classes/transforms/wvtransformconstantstratification/k_dft.html) k wavenumber dimension on the DFT grid
  + [`kl`](/classes/transforms/wvtransformconstantstratification/kl.html) wavenumber dimension
  + [`l_dft`](/classes/transforms/wvtransformconstantstratification/l_dft.html) l wavenumber dimension on the DFT grid
  + [`maxFg`](/classes/transforms/wvtransformconstantstratification/maxfg.html)
  + [`maxFw`](/classes/transforms/wvtransformconstantstratification/maxfw.html)
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformconstantstratification/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`setConjugateToUnity`](/classes/transforms/wvtransformconstantstratification/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
  + [`shouldExcludeConjugates`](/classes/transforms/wvtransformconstantstratification/shouldexcludeconjugates.html) whether the WV grid excludes redundant Hermitian-conjugate wavenumbers
  + [`shouldExcludeNyquist`](/classes/transforms/wvtransformconstantstratification/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
  + [`sin_alpha`](/classes/transforms/wvtransformconstantstratification/sin_alpha.html)
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformconstantstratification/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformconstantstratification/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors


---