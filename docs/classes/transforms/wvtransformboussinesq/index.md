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
      + [`beta`](/classes/transforms/wvtransformboussinesq/beta.html) meridional gradient of the Coriolis parameter
      + [`f`](/classes/transforms/wvtransformboussinesq/f.html) Coriolis parameter
      + [`inertialPeriod`](/classes/transforms/wvtransformboussinesq/inertialperiod.html) inertial period
      + [`latitude`](/classes/transforms/wvtransformboussinesq/latitude.html) central latitude of the simulation
      + [`planetaryRadius`](/classes/transforms/wvtransformboussinesq/planetaryradius.html) radius of the planetary body
      + [`rotationRate`](/classes/transforms/wvtransformboussinesq/rotationrate.html) rotation rate of the planetary body
    + Stratification and reference density
      + [`N2`](/classes/transforms/wvtransformboussinesq/n2.html) Buoyancy frequency squared sampled on the vertical grid.
      + [`N2Function`](/classes/transforms/wvtransformboussinesq/n2function.html) Function returning buoyancy frequency squared at requested depths.
      + [`buoyancyPeriod`](/classes/transforms/wvtransformboussinesq/buoyancyperiod.html)
      + [`dLnN2`](/classes/transforms/wvtransformboussinesq/dlnn2.html) $$\partial_z \ln N^2$$, vertical derivative of the logarithm of squared buoyancy frequency
      + [`rho0`](/classes/transforms/wvtransformboussinesq/rho0.html) Boussinesq reference density.
      + [`rhoFunction`](/classes/transforms/wvtransformboussinesq/rhofunction.html) Function returning the no-motion density profile at requested depths.
      + [`shouldUseTrueNoMotionProfile`](/classes/transforms/wvtransformboussinesq/shouldusetruenomotionprofile.html)
    + Gravity
      + [`g`](/classes/transforms/wvtransformboussinesq/g.html) gravitational acceleration
  + Spatial grid
    + Coordinate axes
      + [`x`](/classes/transforms/wvtransformboussinesq/x.html) dimension
      + [`y`](/classes/transforms/wvtransformboussinesq/y.html) dimension
      + [`z`](/classes/transforms/wvtransformboussinesq/z.html) Vertical coordinate axis.
    + Coordinate arrays
      + [`X`](/classes/transforms/wvtransformboussinesq/x_.html) x-coordinate matrix
      + [`Y`](/classes/transforms/wvtransformboussinesq/y_.html) y-coordinate matrix
      + [`Z`](/classes/transforms/wvtransformboussinesq/z_.html) z-coordinate matrix
      + [`xyzGrid`](/classes/transforms/wvtransformboussinesq/xyzgrid.html)
    + Domain dimensions
      + [`Lx`](/classes/transforms/wvtransformboussinesq/lx.html) length of the x-dimension
      + [`Ly`](/classes/transforms/wvtransformboussinesq/ly.html) length of the y-dimension
      + [`Lz`](/classes/transforms/wvtransformboussinesq/lz.html) length of the z-dimension
    + Resolution and shape
      + [`Nx`](/classes/transforms/wvtransformboussinesq/nx.html) number of grid points in the x-dimension
      + [`Ny`](/classes/transforms/wvtransformboussinesq/ny.html) number of grid points in the y-dimension
      + [`Nz`](/classes/transforms/wvtransformboussinesq/nz.html) points in the third, untransformed, dimension
      + [`spatialMatrixSize`](/classes/transforms/wvtransformboussinesq/spatialmatrixsize.html)
    + Quadrature and integration
      + [`z_int`](/classes/transforms/wvtransformboussinesq/z_int.html) Vertical quadrature weights.
      + [`volumeIntegral`](/classes/transforms/wvtransformboussinesq/volumeintegral.html)
  + Spectral grid
    + Axes and spacing
      + [`kAxis`](/classes/transforms/wvtransformboussinesq/kaxis.html) k coordinate
      + [`lAxis`](/classes/transforms/wvtransformboussinesq/laxis.html) l coordinate
      + [`j`](/classes/transforms/wvtransformboussinesq/j.html) Vertical-mode index axis.
      + [`dk`](/classes/transforms/wvtransformboussinesq/dk.html) wavenumber spacing of the $$k$$ axis
      + [`dl`](/classes/transforms/wvtransformboussinesq/dl.html) wavenumber spacing of the $$l$$ axis
    + Coordinate arrays
      + [`k`](/classes/transforms/wvtransformboussinesq/k.html) wavenumber dimension on the WV grid
      + [`l`](/classes/transforms/wvtransformboussinesq/l.html) wavenumber dimension on the WV grid
      + [`K`](/classes/transforms/wvtransformboussinesq/k_.html) k-coordinate matrix
      + [`L`](/classes/transforms/wvtransformboussinesq/l_.html) l-coordinate matrix
      + [`J`](/classes/transforms/wvtransformboussinesq/j_.html) vertical mode-number matrix
      + [`kljGrid`](/classes/transforms/wvtransformboussinesq/kljgrid.html)
    + Horizontal wavenumber geometry
      + [`Kh`](/classes/transforms/wvtransformboussinesq/kh.html) horizontal wavenumber, $$Kh=\sqrt(K^2+L^2)$$
      + [`K2`](/classes/transforms/wvtransformboussinesq/k2.html) squared horizontal wavenumber, $$K2=K^2+L^2$$
    + Resolution and shape
      + [`Nj`](/classes/transforms/wvtransformboussinesq/nj.html) points in the j-coordinate, `length(z)`
      + [`Nkl`](/classes/transforms/wvtransformboussinesq/nkl.html) length of the combined kl-wavenumber dimension on the WV grid
      + [`spectralMatrixSize`](/classes/transforms/wvtransformboussinesq/spectralmatrixsize.html)
      + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformboussinesq/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
      + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformboussinesq/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
      + [`effectiveJMax`](/classes/transforms/wvtransformboussinesq/effectivejmax.html)
    + Vertical modes and scaling
      + [`verticalModes`](/classes/transforms/wvtransformboussinesq/verticalmodes.html) Vertical eigenmodes used by the transform.
      + [`h_0`](/classes/transforms/wvtransformboussinesq/h_0.html) [Nj 1]
      + [`h_pm`](/classes/transforms/wvtransformboussinesq/h_pm.html) equivalent depth of each wave mode
      + [`Lr2`](/classes/transforms/wvtransformboussinesq/lr2.html) squared Rossby deformation radius of each geostrophic mode
      + [`waveModeVerticalStructureAtIndex`](/classes/transforms/wvtransformboussinesq/wavemodeverticalstructureatindex.html) Return wave vertical-structure factors at one vertical grid index.
  + Transform configuration
    + [`isHydrostatic`](/classes/transforms/wvtransformboussinesq/ishydrostatic.html)
    + [`shouldAntialias`](/classes/transforms/wvtransformboussinesq/shouldantialias.html) whether quadratic antialiasing is enabled
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
  + [`forcingNames`](/classes/transforms/wvtransformboussinesq/forcingnames.html) retrieve the names of all available variables. This preserves
  + [`forcingWithName`](/classes/transforms/wvtransformboussinesq/forcingwithname.html) Return registered forcing objects by name.
  + [`hasClosure`](/classes/transforms/wvtransformboussinesq/hasclosure.html)
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
    + [`exactTotalEnergy`](/classes/transforms/wvtransformboussinesq/exacttotalenergy.html)
    + [`geostrophicEnergy`](/classes/transforms/wvtransformboussinesq/geostrophicenergy.html) total energy, geostrophic
    + [`hasMeanPressureDifference`](/classes/transforms/wvtransformboussinesq/hasmeanpressuredifference.html) Diagnose an MDA mean-pressure difference between the boundaries.
    + [`summarizeDegreesOfFreedom`](/classes/transforms/wvtransformboussinesq/summarizedegreesoffreedom.html) Summarize the spatial grid and active spectral degrees of freedom.
    + [`summarizeEnergyContent`](/classes/transforms/wvtransformboussinesq/summarizeenergycontent.html) displays a summary of the energy content of the fluid
    + [`summarizeModeEnergy`](/classes/transforms/wvtransformboussinesq/summarizemodeenergy.html) List the most energetic modes
    + [`totalEnergy`](/classes/transforms/wvtransformboussinesq/totalenergy.html) horizontally-averaged depth-integrated energy computed spectrally from wave-vortex coefficients
    + [`totalEnergyOfFlowComponent`](/classes/transforms/wvtransformboussinesq/totalenergyofflowcomponent.html)
    + [`totalEnergySpatiallyIntegrated`](/classes/transforms/wvtransformboussinesq/totalenergyspatiallyintegrated.html) horizontally-averaged depth-integrated energy computed in the spatial domain
  + Flow diagnostics
    + [`uvMax`](/classes/transforms/wvtransformboussinesq/uvmax.html) max horizontal fluid speed
    + [`wMax`](/classes/transforms/wvtransformboussinesq/wmax.html) max vertical fluid speed
  + Density validity
    + [`isDensityInValidRange`](/classes/transforms/wvtransformboussinesq/isdensityinvalidrange.html) Test whether total density remains within the no-motion density range.
  + Potential vorticity and enstrophy
    + [`exactPotentialEnstrophy`](/classes/transforms/wvtransformboussinesq/exactpotentialenstrophy.html)
    + [`totalEnstrophy`](/classes/transforms/wvtransformboussinesq/totalenstrophy.html)
    + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformboussinesq/totalenstrophyspatiallyintegrated.html)
  + Spectra
    + Spectral fields
      + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformboussinesq/crossspectrumwithfgtransform.html)
      + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformboussinesq/crossspectrumwithggtransform.html)
      + [`spectrumWithFgTransform`](/classes/transforms/wvtransformboussinesq/spectrumwithfgtransform.html)
      + [`spectrumWithGgTransform`](/classes/transforms/wvtransformboussinesq/spectrumwithggtransform.html)
      + [`transformToKLAxes`](/classes/transforms/wvtransformboussinesq/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
    + Radial wavenumber
      + [`kRadial`](/classes/transforms/wvtransformboussinesq/kradial.html) radial (k,l) wavenumber on the WV grid
      + [`transformToRadialWavenumber`](/classes/transforms/wvtransformboussinesq/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
    + Pseudo-radial wavenumber
      + [`kPseudoRadial`](/classes/transforms/wvtransformboussinesq/kpseudoradial.html)
      + [`transformToPseudoRadialWavenumber`](/classes/transforms/wvtransformboussinesq/transformtopseudoradialwavenumber.html) transforms in the from (j,kRadial) to kPseudoRadial
      + [`transformToPseudoRadialWavenumberA0`](/classes/transforms/wvtransformboussinesq/transformtopseudoradialwavenumbera0.html) transforms in the from (j,kRadial) to kPseudoRadial
      + [`transformToPseudoRadialWavenumberApm`](/classes/transforms/wvtransformboussinesq/transformtopseudoradialwavenumberapm.html) transforms in the from (j,kRadial) to kPseudoRadial
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
  + [`diffX`](/classes/transforms/wvtransformboussinesq/diffx.html)
  + [`diffY`](/classes/transforms/wvtransformboussinesq/diffy.html)
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
  + [`flowComponents`](/classes/transforms/wvtransformboussinesq/flowcomponents.html)
  + [`primaryFlowComponentNames`](/classes/transforms/wvtransformboussinesq/primaryflowcomponentnames.html) retrieve the names of all available variables
  + [`primaryFlowComponentWithName`](/classes/transforms/wvtransformboussinesq/primaryflowcomponentwithname.html) retrieve a WVPrimaryFlowComponent by name
  + [`primaryFlowComponents`](/classes/transforms/wvtransformboussinesq/primaryflowcomponents.html)
  + [`summarizeFlowComponents`](/classes/transforms/wvtransformboussinesq/summarizeflowcomponents.html) Print a table of registered primary and diagnostic components.
  + [`totalFlowComponent`](/classes/transforms/wvtransformboussinesq/totalflowcomponent.html)
+ Inspect wave-vortex coefficients
  + Stored coefficients
    + [`Ap`](/classes/transforms/wvtransformboussinesq/ap.html) Positive-frequency wave and inertial coefficients at reference time `t0`.
    + [`Am`](/classes/transforms/wvtransformboussinesq/am.html) Negative-frequency wave and inertial coefficients at reference time `t0`.
    + [`A0`](/classes/transforms/wvtransformboussinesq/a0.html) Zero-frequency geostrophic and mean-density-anomaly coefficients.
  + Coefficients at the current time
    + [`Apt`](/classes/transforms/wvtransformboussinesq/apt.html) positive-frequency coefficients at current time t
    + [`Amt`](/classes/transforms/wvtransformboussinesq/amt.html) negative-frequency coefficients at current time t
    + [`A0t`](/classes/transforms/wvtransformboussinesq/a0t.html) zero-frequency coefficients at current time t
    + [`waveCoefficientsAtTimeT`](/classes/transforms/wvtransformboussinesq/wavecoefficientsattimet.html)
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
  + [`waveVortexTransformWithExplicitAntialiasing`](/classes/transforms/wvtransformboussinesq/wavevortextransformwithexplicitantialiasing.html)
  + [`waveVortexTransformWithResolution`](/classes/transforms/wvtransformboussinesq/wavevortextransformwithresolution.html) Construct the same transform family at a requested resolution.
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
  + [`A0N`](/classes/transforms/wvtransformboussinesq/a0n.html) matrix component that multiplies $$\tilde{\eta}$$ to compute $$A_0$$.
  + [`A0U`](/classes/transforms/wvtransformboussinesq/a0u.html) matrix component that multiplies $$\tilde{u}$$ to compute $$A_0$$.
  + [`A0V`](/classes/transforms/wvtransformboussinesq/a0v.html) matrix component that multiplies $$\tilde{v}$$ to compute $$A_0$$.
  + [`A0Z`](/classes/transforms/wvtransformboussinesq/a0z.html)
  + [`ApmD`](/classes/transforms/wvtransformboussinesq/apmd.html)
  + [`ApmN`](/classes/transforms/wvtransformboussinesq/apmn.html)
  + [`ApmW`](/classes/transforms/wvtransformboussinesq/apmw.html)
  + [`Feta`](/classes/transforms/wvtransformboussinesq/feta.html)
  + [`Fu`](/classes/transforms/wvtransformboussinesq/fu.html)
  + [`Fv`](/classes/transforms/wvtransformboussinesq/fv.html)
  + [`NA0`](/classes/transforms/wvtransformboussinesq/na0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{\eta}$$.
  + [`NAm`](/classes/transforms/wvtransformboussinesq/nam.html)
  + [`NAp`](/classes/transforms/wvtransformboussinesq/nap.html)
  + [`P0`](/classes/transforms/wvtransformboussinesq/p0.html) Preconditioner for F, size(P)=[Nj 1]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`PA0`](/classes/transforms/wvtransformboussinesq/pa0.html)
  + [`Q0`](/classes/transforms/wvtransformboussinesq/q0.html) Preconditioner for G, size(Q)=[Nj 1]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`UA0`](/classes/transforms/wvtransformboussinesq/ua0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{u}$$.
  + [`UAm`](/classes/transforms/wvtransformboussinesq/uam.html)
  + [`UAp`](/classes/transforms/wvtransformboussinesq/uap.html)
  + [`VA0`](/classes/transforms/wvtransformboussinesq/va0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{v}$$.
  + [`VAm`](/classes/transforms/wvtransformboussinesq/vam.html)
  + [`VAp`](/classes/transforms/wvtransformboussinesq/vap.html)
  + [`WAm`](/classes/transforms/wvtransformboussinesq/wam.html)
  + [`WAp`](/classes/transforms/wvtransformboussinesq/wap.html)
+ Geometry and mode indexing
  + [`buildVerticalModeProjectionOperators`](/classes/transforms/wvtransformboussinesq/buildverticalmodeprojectionoperators.html)
  + [`conjugateDimension`](/classes/transforms/wvtransformboussinesq/conjugatedimension.html) assumed conjugate dimension
  + [`dftConjugateIndex`](/classes/transforms/wvtransformboussinesq/dftconjugateindex.html) legacy vertically replicated conjugate index
  + [`dftPrimaryIndex`](/classes/transforms/wvtransformboussinesq/dftprimaryindex.html) legacy vertically replicated index into the active Fourier storage
  + [`indexFromKLModeNumber`](/classes/transforms/wvtransformboussinesq/indexfromklmodenumber.html) return the linear index into k_wv and l_wv from a mode number
  + [`indexFromModeNumber`](/classes/transforms/wvtransformboussinesq/indexfrommodenumber.html) return the linear index into a spectral matrix given (k,l,j)
  + [`indicesFromDFTGridToWVGrid`](/classes/transforms/wvtransformboussinesq/indicesfromdftgridtowvgrid.html) indices to convert from DFT to WV grid
  + [`indicesFromWVGridToDFTGrid`](/classes/transforms/wvtransformboussinesq/indicesfromwvgridtodftgrid.html) indices to convert from WV to DFT grid
  + [`indicesFromWVGridToFFTWGrid`](/classes/transforms/wvtransformboussinesq/indicesfromwvgridtofftwgrid.html) indices to convert from WV to DFT grid
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
  + [`transformToOmegaAxis`](/classes/transforms/wvtransformboussinesq/transformtoomegaaxis.html) transforms in the from (j,kRadial) to omegaAxis
  + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
  + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
  + [`wvConjugateIndex`](/classes/transforms/wvtransformboussinesq/wvconjugateindex.html) legacy vertically replicated WV conjugate index
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