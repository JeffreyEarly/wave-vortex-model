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
  + [`waveVortexTransformWithExplicitAntialiasing`](/classes/transforms/wvtransformhydrostatic/wavevortextransformwithexplicitantialiasing.html)
+ Inspect wave-vortex coefficients
  + Coefficients at the current time
    + [`A0t`](/classes/transforms/wvtransformhydrostatic/a0t.html) zero-frequency coefficients at current time t
    + [`Amt`](/classes/transforms/wvtransformhydrostatic/amt.html) negative-frequency coefficients at current time t
    + [`Apt`](/classes/transforms/wvtransformhydrostatic/apt.html) positive-frequency coefficients at current time t
    + [`waveCoefficientsAtTimeT`](/classes/transforms/wvtransformhydrostatic/wavecoefficientsattimet.html)
+ Inspect the domain
  + Spatial grid
    + [`z`](/classes/transforms/wvtransformhydrostatic/z.html) z coordinate
    + [`Lx`](/classes/transforms/wvtransformhydrostatic/lx.html) length of the x-dimension
    + [`Ly`](/classes/transforms/wvtransformhydrostatic/ly.html) length of the y-dimension
    + [`Lz`](/classes/transforms/wvtransformhydrostatic/lz.html) length of the z-dimension
    + [`Nx`](/classes/transforms/wvtransformhydrostatic/nx.html) number of grid points in the x-dimension
    + [`Ny`](/classes/transforms/wvtransformhydrostatic/ny.html) number of grid points in the y-dimension
    + [`Nz`](/classes/transforms/wvtransformhydrostatic/nz.html) points in the third, untransformed, dimension
    + [`spatialMatrixSize`](/classes/transforms/wvtransformhydrostatic/spatialmatrixsize.html)
    + [`volumeIntegral`](/classes/transforms/wvtransformhydrostatic/volumeintegral.html)
    + [`x`](/classes/transforms/wvtransformhydrostatic/x.html) dimension
    + [`xyzGrid`](/classes/transforms/wvtransformhydrostatic/xyzgrid.html)
    + [`y`](/classes/transforms/wvtransformhydrostatic/y.html) dimension
    + [`z_int`](/classes/transforms/wvtransformhydrostatic/z_int.html) Quadrature weights for the vertical grid
  + Spectral grid
    + [`Nj`](/classes/transforms/wvtransformhydrostatic/nj.html) points in the j-coordinate, `length(z)`
    + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformhydrostatic/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
    + [`effectiveJMax`](/classes/transforms/wvtransformhydrostatic/effectivejmax.html)
    + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformhydrostatic/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
    + [`j`](/classes/transforms/wvtransformhydrostatic/j.html) vertical mode number
    + [`k`](/classes/transforms/wvtransformhydrostatic/k.html) wavenumber dimension on the WV grid
    + [`kAxis`](/classes/transforms/wvtransformhydrostatic/kaxis.html) k coordinate
    + [`kljGrid`](/classes/transforms/wvtransformhydrostatic/kljgrid.html)
    + [`l`](/classes/transforms/wvtransformhydrostatic/l.html) wavenumber dimension on the WV grid
    + [`lAxis`](/classes/transforms/wvtransformhydrostatic/laxis.html) l coordinate
    + [`spectralMatrixSize`](/classes/transforms/wvtransformhydrostatic/spectralmatrixsize.html)
  + Rotation and stratification
    + [`N2`](/classes/transforms/wvtransformhydrostatic/n2.html) $$N^2(z)$$, squared buoyancy frequency of the no-motion density, $$N^2\equiv - \frac{g}{\rho_0} \frac{\partial \rho_\textrm{nm}}{\partial z}$$
    + [`N2Function`](/classes/transforms/wvtransformhydrostatic/n2function.html) takes $$z$$ values and returns the squared buoyancy frequency of the no-motion density.
    + [`beta`](/classes/transforms/wvtransformhydrostatic/beta.html)
    + [`buoyancyPeriod`](/classes/transforms/wvtransformhydrostatic/buoyancyperiod.html)
    + [`inertialPeriod`](/classes/transforms/wvtransformhydrostatic/inertialperiod.html) inertial period
    + [`latitude`](/classes/transforms/wvtransformhydrostatic/latitude.html) central latitude of the simulation
    + [`rhoFunction`](/classes/transforms/wvtransformhydrostatic/rhofunction.html) eta_true operation needs rhoFunction
    + [`shouldUseTrueNoMotionProfile`](/classes/transforms/wvtransformhydrostatic/shouldusetruenomotionprofile.html)
    + [`verticalModes`](/classes/transforms/wvtransformhydrostatic/verticalmodes.html) instance of the InternalModes class
+ Initialize the flow
  + Waves
    + [`addWaveModes`](/classes/transforms/wvtransformhydrostatic/addwavemodes.html) add amplitudes of the given wave modes
    + [`addWavesWithFrequencySpectrum`](/classes/transforms/wvtransformhydrostatic/addwaveswithfrequencyspectrum.html) add waves with a specified frequency spectrum
    + [`initWithWaveModes`](/classes/transforms/wvtransformhydrostatic/initwithwavemodes.html) initialize with the given wave modes
    + [`removeAllWaves`](/classes/transforms/wvtransformhydrostatic/removeallwaves.html) removes all wave from the model, including inertial oscillations
    + [`setWaveModes`](/classes/transforms/wvtransformhydrostatic/setwavemodes.html) set amplitudes of the given wave modes
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
  + On the model grid
    + [`eta`](/classes/transforms/wvtransformhydrostatic/eta.html) approximate isopycnal deviation
    + [`p`](/classes/transforms/wvtransformhydrostatic/p.html) pressure anomaly
    + [`pi`](/classes/transforms/wvtransformhydrostatic/pi.html) height anomaly
    + [`qgpv`](/classes/transforms/wvtransformhydrostatic/qgpv.html) quasigeostrophic potential vorticity
    + [`rho_bar`](/classes/transforms/wvtransformhydrostatic/rho_bar.html) mean density
    + [`rho_e`](/classes/transforms/wvtransformhydrostatic/rho_e.html) excess density
    + [`rho_nm`](/classes/transforms/wvtransformhydrostatic/rho_nm.html) no-motion density profile
    + [`rho_nm0`](/classes/transforms/wvtransformhydrostatic/rho_nm0.html) $$\rho_\textrm{nm}(z)$$, no-motion density at time `t0`
    + [`rho_total`](/classes/transforms/wvtransformhydrostatic/rho_total.html) total potential density
    + [`ssh`](/classes/transforms/wvtransformhydrostatic/ssh.html) sea-surface height
    + [`ssu`](/classes/transforms/wvtransformhydrostatic/ssu.html) x-component of the fluid velocity at the surface
    + [`ssv`](/classes/transforms/wvtransformhydrostatic/ssv.html) y-component of the fluid velocity at the surface
    + [`u`](/classes/transforms/wvtransformhydrostatic/u.html) x-component of the fluid velocity
    + [`uvMax`](/classes/transforms/wvtransformhydrostatic/uvmax.html) max horizontal fluid speed
    + [`v`](/classes/transforms/wvtransformhydrostatic/v.html) y-component of the fluid velocity
    + [`w`](/classes/transforms/wvtransformhydrostatic/w.html) z-component of the fluid velocity
    + [`wMax`](/classes/transforms/wvtransformhydrostatic/wmax.html) max vertical fluid speed
    + [`zeta_x`](/classes/transforms/wvtransformhydrostatic/zeta_x.html) x-component component of relative vorticity
    + [`zeta_y`](/classes/transforms/wvtransformhydrostatic/zeta_y.html) y-component component of relative vorticity
    + [`zeta_z`](/classes/transforms/wvtransformhydrostatic/zeta_z.html) vertical component of relative vorticity
+ Convert representations
+ Differentiate and integrate fields
  + [`diffX`](/classes/transforms/wvtransformhydrostatic/diffx.html)
  + [`diffY`](/classes/transforms/wvtransformhydrostatic/diffy.html)
  + [`diffZF`](/classes/transforms/wvtransformhydrostatic/diffzf.html) Differentiate an F-grid field with respect to z.
  + [`diffZG`](/classes/transforms/wvtransformhydrostatic/diffzg.html) Differentiate a G-grid field with respect to z.
  + [`intZF`](/classes/transforms/wvtransformhydrostatic/intzf.html) Return the first antiderivative of an F-representation.
  + [`intZG`](/classes/transforms/wvtransformhydrostatic/intzg.html) Return the bottom-zero first antiderivative of a G-representation.
+ Analyze the flow
  + Energy and summaries
    + [`inertialEnergy`](/classes/transforms/wvtransformhydrostatic/inertialenergy.html) total energy of the inertial flow
    + [`waveEnergy`](/classes/transforms/wvtransformhydrostatic/waveenergy.html) total energy of the geostrophic flow
    + [`exactTotalEnergy`](/classes/transforms/wvtransformhydrostatic/exacttotalenergy.html)
    + [`geostrophicEnergy`](/classes/transforms/wvtransformhydrostatic/geostrophicenergy.html) total energy, geostrophic
  + Potential vorticity and enstrophy
    + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformhydrostatic/enstrophyfluxfromf0.html)
    + [`exactPotentialEnstrophy`](/classes/transforms/wvtransformhydrostatic/exactpotentialenstrophy.html)
    + [`totalEnstrophy`](/classes/transforms/wvtransformhydrostatic/totalenstrophy.html)
    + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformhydrostatic/totalenstrophyspatiallyintegrated.html)
  + Spectra
    + [`addGMSpectrum`](/classes/transforms/wvtransformhydrostatic/addgmspectrum.html) add waves following a Garrett-Munk spectrum
    + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformhydrostatic/crossspectrumwithfgtransform.html)
    + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformhydrostatic/crossspectrumwithggtransform.html)
    + [`initWavesWithFrequencySpectrum`](/classes/transforms/wvtransformhydrostatic/initwaveswithfrequencyspectrum.html) initialize with waves of a specified frequency spectrum
    + [`initWithAlternativeSpectrum`](/classes/transforms/wvtransformhydrostatic/initwithalternativespectrum.html) initialize with an alternative formulation of the GM spectrum in the wavenumber domain.
    + [`initWithGMSpectrum`](/classes/transforms/wvtransformhydrostatic/initwithgmspectrum.html) initialize the wave field following a Garrett-Munk spectrum
    + [`transformToPseudoRadialWavenumber`](/classes/transforms/wvtransformhydrostatic/transformtopseudoradialwavenumber.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberA0`](/classes/transforms/wvtransformhydrostatic/transformtopseudoradialwavenumbera0.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberApm`](/classes/transforms/wvtransformhydrostatic/transformtopseudoradialwavenumberapm.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToRadialWavenumber`](/classes/transforms/wvtransformhydrostatic/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Inspect wave-vortex coefficients
+ Inspect the domain
+ Initialize the flow
+ Evaluate physical fields
+ Convert representations
+ Analyze the flow
+ Projection and reconstruction coefficients
  + [`A0N`](/classes/transforms/wvtransformhydrostatic/a0n.html) matrix component that multiplies $$\tilde{\eta}$$ to compute $$A_0$$.
  + [`A0U`](/classes/transforms/wvtransformhydrostatic/a0u.html) matrix component that multiplies $$\tilde{u}$$ to compute $$A_0$$.
  + [`A0V`](/classes/transforms/wvtransformhydrostatic/a0v.html) matrix component that multiplies $$\tilde{v}$$ to compute $$A_0$$.
  + [`A0Z`](/classes/transforms/wvtransformhydrostatic/a0z.html)
  + [`ApmD`](/classes/transforms/wvtransformhydrostatic/apmd.html)
  + [`ApmN`](/classes/transforms/wvtransformhydrostatic/apmn.html)
  + [`Feta`](/classes/transforms/wvtransformhydrostatic/feta.html)
  + [`Fu`](/classes/transforms/wvtransformhydrostatic/fu.html)
  + [`Fv`](/classes/transforms/wvtransformhydrostatic/fv.html)
  + [`NA0`](/classes/transforms/wvtransformhydrostatic/na0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{\eta}$$.
  + [`NAm`](/classes/transforms/wvtransformhydrostatic/nam.html)
  + [`NAp`](/classes/transforms/wvtransformhydrostatic/nap.html)
  + [`P0`](/classes/transforms/wvtransformhydrostatic/p0.html) Preconditioner for F, size(P)=[Nj 1]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`PA0`](/classes/transforms/wvtransformhydrostatic/pa0.html)
  + [`Q0`](/classes/transforms/wvtransformhydrostatic/q0.html) Preconditioner for G, size(Q)=[Nj 1]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`UA0`](/classes/transforms/wvtransformhydrostatic/ua0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{u}$$.
  + [`UAm`](/classes/transforms/wvtransformhydrostatic/uam.html)
  + [`UAp`](/classes/transforms/wvtransformhydrostatic/uap.html)
  + [`VA0`](/classes/transforms/wvtransformhydrostatic/va0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{v}$$.
  + [`VAm`](/classes/transforms/wvtransformhydrostatic/vam.html)
  + [`VAp`](/classes/transforms/wvtransformhydrostatic/vap.html)
  + [`WAm`](/classes/transforms/wvtransformhydrostatic/wam.html)
  + [`WAp`](/classes/transforms/wvtransformhydrostatic/wap.html)
+ Geometry and mode indexing
  + [`conjugateDimension`](/classes/transforms/wvtransformhydrostatic/conjugatedimension.html) assumed conjugate dimension
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
  + [`transformToOmegaAxis`](/classes/transforms/wvtransformhydrostatic/transformtoomegaaxis.html) transforms in the from (j,kRadial) to omegaAxis
  + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
  + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
  + [`waveModeVerticalStructureAtIndex`](/classes/transforms/wvtransformhydrostatic/wavemodeverticalstructureatindex.html) Return wave vertical-structure factors at one vertical grid index.
+ Spectral transforms and operators
  + [`FMatrix`](/classes/transforms/wvtransformhydrostatic/fmatrix.html) transformation matrix $$F_g$$
  + [`FinvMatrix`](/classes/transforms/wvtransformhydrostatic/finvmatrix.html) transformation matrix $$F_g^{-1}$$
  + [`GMatrix`](/classes/transforms/wvtransformhydrostatic/gmatrix.html) transformation matrix $$G_g$$
  + [`GinvMatrix`](/classes/transforms/wvtransformhydrostatic/ginvmatrix.html) transformation matrix $$G_g^{-1}$$
  + [`PF0`](/classes/transforms/wvtransformhydrostatic/pf0.html) size(PF,PG)=[Nj x Nz]
  + [`PF0inv`](/classes/transforms/wvtransformhydrostatic/pf0inv.html) Transformation matrices
  + [`QG0`](/classes/transforms/wvtransformhydrostatic/qg0.html) Preconditioned G-mode forward transformation
  + [`QG0inv`](/classes/transforms/wvtransformhydrostatic/qg0inv.html) Preconditioned G-mode inverse transformation
  + [`boussinesqTransform`](/classes/transforms/wvtransformhydrostatic/boussinesqtransform.html)
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformhydrostatic/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformhydrostatic/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`fastTransform`](/classes/transforms/wvtransformhydrostatic/fasttransform.html) fast transform object
  + [`spectrumWithFgTransform`](/classes/transforms/wvtransformhydrostatic/spectrumwithfgtransform.html)
  + [`spectrumWithGgTransform`](/classes/transforms/wvtransformhydrostatic/spectrumwithggtransform.html)
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformhydrostatic/transformfromspatialdomainwithfio.html)
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformhydrostatic/transformfromspatialdomainwithfourier.html)
  + [`transformToKLAxes`](/classes/transforms/wvtransformhydrostatic/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainwithfourieratposition.html)
  + [`transformWithG_wg`](/classes/transforms/wvtransformhydrostatic/transformwithg_wg.html)
+ Nonlinear flux and forcing internals
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
  + [`geostrophicComponent`](/classes/transforms/wvtransformhydrostatic/geostrophiccomponent.html) returns the geostrophic flow component
  + [`mdaEnergy`](/classes/transforms/wvtransformhydrostatic/mdaenergy.html) total energy of the mean density anomaly
  + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformhydrostatic/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
  + [`waveComponent`](/classes/transforms/wvtransformhydrostatic/wavecomponent.html) returns the internal gravity wave flow component
  + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformhydrostatic/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
  + [`inertialComponent`](/classes/transforms/wvtransformhydrostatic/inertialcomponent.html) returns the inertial oscillation flow component
  + [`mdaComponent`](/classes/transforms/wvtransformhydrostatic/mdacomponent.html) returns the mean density anomaly component
  + [`J`](/classes/transforms/wvtransformhydrostatic/j_.html) j-coordinate matrix
  + [`K`](/classes/transforms/wvtransformhydrostatic/k_.html) k-coordinate matrix
  + [`K2`](/classes/transforms/wvtransformhydrostatic/k2.html) squared horizontal wavenumber, $$K2=K^2+L^2$$
  + [`Kh`](/classes/transforms/wvtransformhydrostatic/kh.html) horizontal wavenumber, $$Kh=\sqrt(K^2+L^2)$$
  + [`L`](/classes/transforms/wvtransformhydrostatic/l_.html) l-coordinate matrix
  + [`Lr2`](/classes/transforms/wvtransformhydrostatic/lr2.html) squared Rossby radius
  + [`Nk_dft`](/classes/transforms/wvtransformhydrostatic/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
  + [`Nkl`](/classes/transforms/wvtransformhydrostatic/nkl.html) length of the combined kl-wavenumber dimension on the WV grid
  + [`Nl_dft`](/classes/transforms/wvtransformhydrostatic/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
  + [`Omega`](/classes/transforms/wvtransformhydrostatic/omega.html)
  + [`X`](/classes/transforms/wvtransformhydrostatic/x_.html) x-coordinate matrix
  + [`Y`](/classes/transforms/wvtransformhydrostatic/y_.html) y-coordinate matrix
  + [`Z`](/classes/transforms/wvtransformhydrostatic/z_.html) z-coordinate matrix
  + [`chebfunForZArray`](/classes/transforms/wvtransformhydrostatic/chebfunforzarray.html)
  + [`conjPhase`](/classes/transforms/wvtransformhydrostatic/conjphase.html) phase of the Am wave modes
  + [`dLnN2`](/classes/transforms/wvtransformhydrostatic/dlnn2.html) $$\frac{\partial \ln N^2}{\partial z}$$, vertical variation of the log of the squared buoyancy frequency
  + [`dftConjugateIndices2D`](/classes/transforms/wvtransformhydrostatic/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
  + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformhydrostatic/dftprimaryindices2d.html) index into the DFT grid of each WV mode
  + [`dk`](/classes/transforms/wvtransformhydrostatic/dk.html) wavenumber spacing of the $$k$$ axis
  + [`dl`](/classes/transforms/wvtransformhydrostatic/dl.html) wavenumber spacing of the $$l$$ axis
  + [`f`](/classes/transforms/wvtransformhydrostatic/f.html) Coriolis parameter
  + [`g`](/classes/transforms/wvtransformhydrostatic/g.html) gravity of Earth
  + [`geometryFromFile`](/classes/transforms/wvtransformhydrostatic/geometryfromfile.html)
  + [`h_0`](/classes/transforms/wvtransformhydrostatic/h_0.html) [Nj 1]
  + [`h_pm`](/classes/transforms/wvtransformhydrostatic/h_pm.html)
  + [`iOmega`](/classes/transforms/wvtransformhydrostatic/iomega.html)
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformhydrostatic/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isDensityInValidRange`](/classes/transforms/wvtransformhydrostatic/isdensityinvalidrange.html) checks if the density field is a valid adiabatic re-arrangement of the base state
  + [`isHermitian`](/classes/transforms/wvtransformhydrostatic/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`kPseudoRadial`](/classes/transforms/wvtransformhydrostatic/kpseudoradial.html)
  + [`kRadial`](/classes/transforms/wvtransformhydrostatic/kradial.html) radial (k,l) wavenumber on the WV grid
  + [`k_dft`](/classes/transforms/wvtransformhydrostatic/k_dft.html) k wavenumber dimension on the DFT grid
  + [`kl`](/classes/transforms/wvtransformhydrostatic/kl.html) wavenumber dimension
  + [`l_dft`](/classes/transforms/wvtransformhydrostatic/l_dft.html) l wavenumber dimension on the DFT grid
  + [`maxFg`](/classes/transforms/wvtransformhydrostatic/maxfg.html)
  + [`maxFw`](/classes/transforms/wvtransformhydrostatic/maxfw.html)
  + [`phase`](/classes/transforms/wvtransformhydrostatic/phase.html) phase of the Ap wave modes
  + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformhydrostatic/placeparticlesonisopycnal.html) places Lagrangian particles along a specified isopycnal
  + [`planetaryRadius`](/classes/transforms/wvtransformhydrostatic/planetaryradius.html) radius of the planetary body
  + [`psi`](/classes/transforms/wvtransformhydrostatic/psi.html) geostrophic streamfunction
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformhydrostatic/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`rho0`](/classes/transforms/wvtransformhydrostatic/rho0.html) , dLnN2
  + [`rotationRate`](/classes/transforms/wvtransformhydrostatic/rotationrate.html) rotation rate of the planetary body
  + [`setConjugateToUnity`](/classes/transforms/wvtransformhydrostatic/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
  + [`shouldAntialias`](/classes/transforms/wvtransformhydrostatic/shouldantialias.html) whether the WV grid includes quadratically aliased wavenumbers
  + [`shouldExcludeConjugates`](/classes/transforms/wvtransformhydrostatic/shouldexcludeconjugates.html) whether the WV grid excludes redundant Hermitian-conjugate wavenumbers
  + [`shouldExcludeNyquist`](/classes/transforms/wvtransformhydrostatic/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformhydrostatic/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformhydrostatic/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors


---