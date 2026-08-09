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
  + [`waveVortexTransformWithExplicitAntialiasing`](/classes/transforms/wvtransformboussinesq/wavevortextransformwithexplicitantialiasing.html)
+ Inspect wave-vortex coefficients
  + Coefficients at the current time
    + [`A0t`](/classes/transforms/wvtransformboussinesq/a0t.html) zero-frequency coefficients at current time t
    + [`Amt`](/classes/transforms/wvtransformboussinesq/amt.html) negative-frequency coefficients at current time t
    + [`Apt`](/classes/transforms/wvtransformboussinesq/apt.html) positive-frequency coefficients at current time t
    + [`waveCoefficientsAtTimeT`](/classes/transforms/wvtransformboussinesq/wavecoefficientsattimet.html)
+ Inspect the domain
  + Spatial grid
    + [`z`](/classes/transforms/wvtransformboussinesq/z.html) z coordinate
    + [`Lx`](/classes/transforms/wvtransformboussinesq/lx.html) length of the x-dimension
    + [`Ly`](/classes/transforms/wvtransformboussinesq/ly.html) length of the y-dimension
    + [`Lz`](/classes/transforms/wvtransformboussinesq/lz.html) length of the z-dimension
    + [`Nx`](/classes/transforms/wvtransformboussinesq/nx.html) number of grid points in the x-dimension
    + [`Ny`](/classes/transforms/wvtransformboussinesq/ny.html) number of grid points in the y-dimension
    + [`Nz`](/classes/transforms/wvtransformboussinesq/nz.html) points in the third, untransformed, dimension
    + [`spatialMatrixSize`](/classes/transforms/wvtransformboussinesq/spatialmatrixsize.html)
    + [`volumeIntegral`](/classes/transforms/wvtransformboussinesq/volumeintegral.html)
    + [`x`](/classes/transforms/wvtransformboussinesq/x.html) dimension
    + [`xyzGrid`](/classes/transforms/wvtransformboussinesq/xyzgrid.html)
    + [`y`](/classes/transforms/wvtransformboussinesq/y.html) dimension
    + [`z_int`](/classes/transforms/wvtransformboussinesq/z_int.html) Quadrature weights for the vertical grid
  + Spectral grid
    + [`Nj`](/classes/transforms/wvtransformboussinesq/nj.html) points in the j-coordinate, `length(z)`
    + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformboussinesq/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
    + [`effectiveJMax`](/classes/transforms/wvtransformboussinesq/effectivejmax.html)
    + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformboussinesq/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
    + [`j`](/classes/transforms/wvtransformboussinesq/j.html) vertical mode number
    + [`k`](/classes/transforms/wvtransformboussinesq/k.html) wavenumber dimension on the WV grid
    + [`kAxis`](/classes/transforms/wvtransformboussinesq/kaxis.html) k coordinate
    + [`kljGrid`](/classes/transforms/wvtransformboussinesq/kljgrid.html)
    + [`l`](/classes/transforms/wvtransformboussinesq/l.html) wavenumber dimension on the WV grid
    + [`lAxis`](/classes/transforms/wvtransformboussinesq/laxis.html) l coordinate
    + [`spectralMatrixSize`](/classes/transforms/wvtransformboussinesq/spectralmatrixsize.html)
  + Rotation and stratification
    + [`N2`](/classes/transforms/wvtransformboussinesq/n2.html) $$N^2(z)$$, squared buoyancy frequency of the no-motion density, $$N^2\equiv - \frac{g}{\rho_0} \frac{\partial \rho_\textrm{nm}}{\partial z}$$
    + [`N2Function`](/classes/transforms/wvtransformboussinesq/n2function.html) takes $$z$$ values and returns the squared buoyancy frequency of the no-motion density.
    + [`beta`](/classes/transforms/wvtransformboussinesq/beta.html)
    + [`buoyancyPeriod`](/classes/transforms/wvtransformboussinesq/buoyancyperiod.html)
    + [`inertialPeriod`](/classes/transforms/wvtransformboussinesq/inertialperiod.html) inertial period
    + [`latitude`](/classes/transforms/wvtransformboussinesq/latitude.html) central latitude of the simulation
    + [`rhoFunction`](/classes/transforms/wvtransformboussinesq/rhofunction.html) eta_true operation needs rhoFunction
    + [`shouldUseTrueNoMotionProfile`](/classes/transforms/wvtransformboussinesq/shouldusetruenomotionprofile.html)
    + [`verticalModes`](/classes/transforms/wvtransformboussinesq/verticalmodes.html) instance of the InternalModes class
+ Initialize the flow
  + Waves
    + [`addWaveModes`](/classes/transforms/wvtransformboussinesq/addwavemodes.html) add amplitudes of the given wave modes
    + [`addWavesWithFrequencySpectrum`](/classes/transforms/wvtransformboussinesq/addwaveswithfrequencyspectrum.html) add waves with a specified frequency spectrum
    + [`initWithWaveModes`](/classes/transforms/wvtransformboussinesq/initwithwavemodes.html) initialize with the given wave modes
    + [`removeAllWaves`](/classes/transforms/wvtransformboussinesq/removeallwaves.html) removes all wave from the model, including inertial oscillations
    + [`setWaveModes`](/classes/transforms/wvtransformboussinesq/setwavemodes.html) set amplitudes of the given wave modes
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
  + On the model grid
    + [`eta`](/classes/transforms/wvtransformboussinesq/eta.html) approximate isopycnal deviation
    + [`p`](/classes/transforms/wvtransformboussinesq/p.html) pressure anomaly
    + [`pi`](/classes/transforms/wvtransformboussinesq/pi.html) height anomaly
    + [`qgpv`](/classes/transforms/wvtransformboussinesq/qgpv.html) quasigeostrophic potential vorticity
    + [`rho_bar`](/classes/transforms/wvtransformboussinesq/rho_bar.html) mean density
    + [`rho_e`](/classes/transforms/wvtransformboussinesq/rho_e.html) excess density
    + [`rho_nm`](/classes/transforms/wvtransformboussinesq/rho_nm.html) no-motion density profile
    + [`rho_nm0`](/classes/transforms/wvtransformboussinesq/rho_nm0.html) $$\rho_\textrm{nm}(z)$$, no-motion density at time `t0`
    + [`rho_total`](/classes/transforms/wvtransformboussinesq/rho_total.html) total potential density
    + [`ssh`](/classes/transforms/wvtransformboussinesq/ssh.html) sea-surface height
    + [`ssu`](/classes/transforms/wvtransformboussinesq/ssu.html) x-component of the fluid velocity at the surface
    + [`ssv`](/classes/transforms/wvtransformboussinesq/ssv.html) y-component of the fluid velocity at the surface
    + [`u`](/classes/transforms/wvtransformboussinesq/u.html) x-component of the fluid velocity
    + [`uvMax`](/classes/transforms/wvtransformboussinesq/uvmax.html) max horizontal fluid speed
    + [`v`](/classes/transforms/wvtransformboussinesq/v.html) y-component of the fluid velocity
    + [`w`](/classes/transforms/wvtransformboussinesq/w.html) z-component of the fluid velocity
    + [`wMax`](/classes/transforms/wvtransformboussinesq/wmax.html) max vertical fluid speed
    + [`zeta_x`](/classes/transforms/wvtransformboussinesq/zeta_x.html) x-component component of relative vorticity
    + [`zeta_y`](/classes/transforms/wvtransformboussinesq/zeta_y.html) y-component component of relative vorticity
    + [`zeta_z`](/classes/transforms/wvtransformboussinesq/zeta_z.html) vertical component of relative vorticity
+ Convert representations
  + Physical fields and coefficients
    + [`transformUVWEtaToWaveVortex`](/classes/transforms/wvtransformboussinesq/transformuvwetatowavevortex.html) transform momentum variables $$(u,v,w,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
+ Differentiate and integrate fields
  + [`diffX`](/classes/transforms/wvtransformboussinesq/diffx.html)
  + [`diffY`](/classes/transforms/wvtransformboussinesq/diffy.html)
  + [`diffZF`](/classes/transforms/wvtransformboussinesq/diffzf.html) Differentiate an F-grid field with respect to z.
  + [`diffZG`](/classes/transforms/wvtransformboussinesq/diffzg.html) Differentiate a G-grid field with respect to z.
  + [`intZF`](/classes/transforms/wvtransformboussinesq/intzf.html) Return the first antiderivative of an F-representation.
  + [`intZG`](/classes/transforms/wvtransformboussinesq/intzg.html) Return the bottom-zero first antiderivative of a G-representation.
+ Analyze the flow
  + Energy and summaries
    + [`inertialEnergy`](/classes/transforms/wvtransformboussinesq/inertialenergy.html) total energy of the inertial flow
    + [`waveEnergy`](/classes/transforms/wvtransformboussinesq/waveenergy.html) total energy of the geostrophic flow
    + [`exactTotalEnergy`](/classes/transforms/wvtransformboussinesq/exacttotalenergy.html)
    + [`geostrophicEnergy`](/classes/transforms/wvtransformboussinesq/geostrophicenergy.html) total energy, geostrophic
  + Potential vorticity and enstrophy
    + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformboussinesq/enstrophyfluxfromf0.html)
    + [`exactPotentialEnstrophy`](/classes/transforms/wvtransformboussinesq/exactpotentialenstrophy.html)
    + [`totalEnstrophy`](/classes/transforms/wvtransformboussinesq/totalenstrophy.html)
    + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformboussinesq/totalenstrophyspatiallyintegrated.html)
  + Spectra
    + [`addGMSpectrum`](/classes/transforms/wvtransformboussinesq/addgmspectrum.html) add waves following a Garrett-Munk spectrum
    + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformboussinesq/crossspectrumwithfgtransform.html)
    + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformboussinesq/crossspectrumwithggtransform.html)
    + [`initWavesWithFrequencySpectrum`](/classes/transforms/wvtransformboussinesq/initwaveswithfrequencyspectrum.html) initialize with waves of a specified frequency spectrum
    + [`initWithAlternativeSpectrum`](/classes/transforms/wvtransformboussinesq/initwithalternativespectrum.html) initialize with an alternative formulation of the GM spectrum in the wavenumber domain.
    + [`initWithGMSpectrum`](/classes/transforms/wvtransformboussinesq/initwithgmspectrum.html) initialize the wave field following a Garrett-Munk spectrum
    + [`transformToPseudoRadialWavenumber`](/classes/transforms/wvtransformboussinesq/transformtopseudoradialwavenumber.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberA0`](/classes/transforms/wvtransformboussinesq/transformtopseudoradialwavenumbera0.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberApm`](/classes/transforms/wvtransformboussinesq/transformtopseudoradialwavenumberapm.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToRadialWavenumber`](/classes/transforms/wvtransformboussinesq/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Inspect wave-vortex coefficients
+ Inspect the domain
+ Initialize the flow
+ Evaluate physical fields
+ Convert representations
+ Analyze the flow
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
  + [`waveModeVerticalStructureAtIndex`](/classes/transforms/wvtransformboussinesq/wavemodeverticalstructureatindex.html) Return wave vertical-structure factors at one vertical grid index.
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
  + [`spectrumWithFgTransform`](/classes/transforms/wvtransformboussinesq/spectrumwithfgtransform.html)
  + [`spectrumWithGgTransform`](/classes/transforms/wvtransformboussinesq/spectrumwithggtransform.html)
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformboussinesq/transformfromspatialdomainwithfio.html)
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformboussinesq/transformfromspatialdomainwithfourier.html)
  + [`transformFromSpatialDomainWithG_w`](/classes/transforms/wvtransformboussinesq/transformfromspatialdomainwithg_w.html)
  + [`transformToKLAxes`](/classes/transforms/wvtransformboussinesq/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
  + [`transformToSpatialDomainWithFg`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithfg.html) arguments
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithfourieratposition.html)
  + [`transformToSpatialDomainWithFw`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithfw.html)
  + [`transformToSpatialDomainWithGg`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithgg.html) arguments
  + [`transformToSpatialDomainWithGw`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainwithgw.html)
  + [`transformWithG_wg`](/classes/transforms/wvtransformboussinesq/transformwithg_wg.html)
+ Nonlinear flux and forcing internals
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
  + [`geostrophicComponent`](/classes/transforms/wvtransformboussinesq/geostrophiccomponent.html) returns the geostrophic flow component
  + [`mdaEnergy`](/classes/transforms/wvtransformboussinesq/mdaenergy.html) total energy of the mean density anomaly
  + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformboussinesq/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
  + [`waveComponent`](/classes/transforms/wvtransformboussinesq/wavecomponent.html) returns the internal gravity wave flow component
  + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformboussinesq/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
  + [`inertialComponent`](/classes/transforms/wvtransformboussinesq/inertialcomponent.html) returns the inertial oscillation flow component
  + [`mdaComponent`](/classes/transforms/wvtransformboussinesq/mdacomponent.html) returns the mean density anomaly component
  + [`Ddelta`](/classes/transforms/wvtransformboussinesq/ddelta.html)
  + [`J`](/classes/transforms/wvtransformboussinesq/j_.html) j-coordinate matrix
  + [`K`](/classes/transforms/wvtransformboussinesq/k_.html) k-coordinate matrix
  + [`K2`](/classes/transforms/wvtransformboussinesq/k2.html) squared horizontal wavenumber, $$K2=K^2+L^2$$
  + [`K2unique`](/classes/transforms/wvtransformboussinesq/k2unique.html) unique squared-wavenumbers
  + [`K2uniqueK2Map`](/classes/transforms/wvtransformboussinesq/k2uniquek2map.html) cell array Nk in length. Each cell contains indices back to K2
  + [`Kh`](/classes/transforms/wvtransformboussinesq/kh.html) horizontal wavenumber, $$Kh=\sqrt(K^2+L^2)$$
  + [`L`](/classes/transforms/wvtransformboussinesq/l_.html) l-coordinate matrix
  + [`Lr2`](/classes/transforms/wvtransformboussinesq/lr2.html) squared Rossby radius
  + [`Nk_dft`](/classes/transforms/wvtransformboussinesq/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
  + [`Nkl`](/classes/transforms/wvtransformboussinesq/nkl.html) length of the combined kl-wavenumber dimension on the WV grid
  + [`Nl_dft`](/classes/transforms/wvtransformboussinesq/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
  + [`Omega`](/classes/transforms/wvtransformboussinesq/omega.html)
  + [`Ppm`](/classes/transforms/wvtransformboussinesq/ppm.html) Preconditioner for F, size(P)=[Nj x Nk]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`Qpm`](/classes/transforms/wvtransformboussinesq/qpm.html) Preconditioner for G, size(Q)=[Nj x Nk]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`X`](/classes/transforms/wvtransformboussinesq/x_.html) x-coordinate matrix
  + [`Y`](/classes/transforms/wvtransformboussinesq/y_.html) y-coordinate matrix
  + [`Z`](/classes/transforms/wvtransformboussinesq/z_.html) z-coordinate matrix
  + [`chebfunForZArray`](/classes/transforms/wvtransformboussinesq/chebfunforzarray.html)
  + [`conjPhase`](/classes/transforms/wvtransformboussinesq/conjphase.html) phase of the Am wave modes
  + [`dLnN2`](/classes/transforms/wvtransformboussinesq/dlnn2.html) $$\frac{\partial \ln N^2}{\partial z}$$, vertical variation of the log of the squared buoyancy frequency
  + [`delta_uhat`](/classes/transforms/wvtransformboussinesq/delta_uhat.html)
  + [`delta_vhat`](/classes/transforms/wvtransformboussinesq/delta_vhat.html)
  + [`dftConjugateIndices2D`](/classes/transforms/wvtransformboussinesq/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
  + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformboussinesq/dftprimaryindices2d.html) index into the DFT grid of each WV mode
  + [`dk`](/classes/transforms/wvtransformboussinesq/dk.html) wavenumber spacing of the $$k$$ axis
  + [`dl`](/classes/transforms/wvtransformboussinesq/dl.html) wavenumber spacing of the $$l$$ axis
  + [`f`](/classes/transforms/wvtransformboussinesq/f.html) Coriolis parameter
  + [`g`](/classes/transforms/wvtransformboussinesq/g.html) gravity of Earth
  + [`geometryFromFile`](/classes/transforms/wvtransformboussinesq/geometryfromfile.html)
  + [`h_0`](/classes/transforms/wvtransformboussinesq/h_0.html) [Nj 1]
  + [`h_pm`](/classes/transforms/wvtransformboussinesq/h_pm.html) equivalent depth of each wave mode
  + [`iK2unique`](/classes/transforms/wvtransformboussinesq/ik2unique.html) map from 2-dim K2, to 1-dim K2unique
  + [`iOmega`](/classes/transforms/wvtransformboussinesq/iomega.html)
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformboussinesq/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isDensityInValidRange`](/classes/transforms/wvtransformboussinesq/isdensityinvalidrange.html) checks if the density field is a valid adiabatic re-arrangement of the base state
  + [`isHermitian`](/classes/transforms/wvtransformboussinesq/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`kPseudoRadial`](/classes/transforms/wvtransformboussinesq/kpseudoradial.html)
  + [`kRadial`](/classes/transforms/wvtransformboussinesq/kradial.html) radial (k,l) wavenumber on the WV grid
  + [`k_dft`](/classes/transforms/wvtransformboussinesq/k_dft.html) k wavenumber dimension on the DFT grid
  + [`kl`](/classes/transforms/wvtransformboussinesq/kl.html) wavenumber dimension
  + [`l_dft`](/classes/transforms/wvtransformboussinesq/l_dft.html) l wavenumber dimension on the DFT grid
  + [`maxFg`](/classes/transforms/wvtransformboussinesq/maxfg.html)
  + [`maxFw`](/classes/transforms/wvtransformboussinesq/maxfw.html)
  + [`nK2unique`](/classes/transforms/wvtransformboussinesq/nk2unique.html) number of unique squared-wavenumbers
  + [`phase`](/classes/transforms/wvtransformboussinesq/phase.html) phase of the Ap wave modes
  + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformboussinesq/placeparticlesonisopycnal.html) places Lagrangian particles along a specified isopycnal
  + [`planetaryRadius`](/classes/transforms/wvtransformboussinesq/planetaryradius.html) radius of the planetary body
  + [`psi`](/classes/transforms/wvtransformboussinesq/psi.html) geostrophic streamfunction
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformboussinesq/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`rho0`](/classes/transforms/wvtransformboussinesq/rho0.html) , dLnN2
  + [`rotationRate`](/classes/transforms/wvtransformboussinesq/rotationrate.html) rotation rate of the planetary body
  + [`setConjugateToUnity`](/classes/transforms/wvtransformboussinesq/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
  + [`shouldAntialias`](/classes/transforms/wvtransformboussinesq/shouldantialias.html) whether the WV grid includes quadratically aliased wavenumbers
  + [`shouldExcludeConjugates`](/classes/transforms/wvtransformboussinesq/shouldexcludeconjugates.html) whether the WV grid excludes redundant Hermitian-conjugate wavenumbers
  + [`shouldExcludeNyquist`](/classes/transforms/wvtransformboussinesq/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformboussinesq/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformboussinesq/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors
  + [`wvBuffer`](/classes/transforms/wvtransformboussinesq/wvbuffer.html)


---