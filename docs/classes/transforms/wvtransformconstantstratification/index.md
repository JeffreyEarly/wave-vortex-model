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

A class for disentangling hydrostatic waves and vortices in variable stratification


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransformHydrostatic < <a href="/classes/wvtransform/" title="WVTransform">WVTransform</a></code></pre></div></div>

## Overview
 
To initialization an instance of the WVTransformHydrostatic class you
must specific the domain size, the number of grid points and *either*
the density profile or the stratification profile.
 
```matlab
N0 = 3*2*pi/3600;
L_gm = 1300;
N2 = @(z) N0*N0*exp(2*z/L_gm);
wvt = WVTransformHydrostatic([100e3, 100e3, 4000],[64, 64, 65], N2=N2,latitude=30);
```
 
               



## Topics
+ Initialization
  + [`WVTransformConstantStratification`](/classes/transforms/wvtransformconstantstratification/wvtransformconstantstratification.html) create a wave-vortex transform for variable stratification
  + [`speedTest`](/classes/transforms/wvtransformconstantstratification/speedtest.html) Initialize a WVTransformConstantStratification instance from an existing file
+ Primary flow components
  + [`geostrophicComponent`](/classes/transforms/wvtransformconstantstratification/geostrophiccomponent.html) returns the geostrophic flow component
  + [`waveComponent`](/classes/transforms/wvtransformconstantstratification/wavecomponent.html) returns the internal gravity wave flow component
  + [`inertialComponent`](/classes/transforms/wvtransformconstantstratification/inertialcomponent.html) returns the inertial oscillation flow component
  + [`mdaComponent`](/classes/transforms/wvtransformconstantstratification/mdacomponent.html) returns the mean density anomaly component
+ Stratification
  + [`rho_nm`](/classes/transforms/wvtransformconstantstratification/rho_nm.html) no-motion density profile
  + [`N2`](/classes/transforms/wvtransformconstantstratification/n2.html) $$N^2(z)$$, squared buoyancy frequency of the no-motion density, $$N^2\equiv - \frac{g}{\rho_0} \frac{\partial \rho_\textrm{nm}}{\partial z}$$
  + [`dLnN2`](/classes/transforms/wvtransformconstantstratification/dlnn2.html) $$\frac{\partial \ln N^2}{\partial z}$$, vertical variation of the log of the squared buoyancy frequency
  + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformconstantstratification/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
  + Vertical modes
    + [`FMatrix`](/classes/transforms/wvtransformconstantstratification/fmatrix.html) transformation matrix $$F_g$$
    + [`FinvMatrix`](/classes/transforms/wvtransformconstantstratification/finvmatrix.html) transformation matrix $$F_g^{-1}$$
    + [`GMatrix`](/classes/transforms/wvtransformconstantstratification/gmatrix.html) transformation matrix $$G_g$$
    + [`GinvMatrix`](/classes/transforms/wvtransformconstantstratification/ginvmatrix.html) transformation matrix $$G_g^{-1}$$
  + Validation
    + [`isDensityInValidRange`](/classes/transforms/wvtransformconstantstratification/isdensityinvalidrange.html) checks if the density field is a valid adiabatic re-arrangement of the base state
+ Initial conditions
  + Waves
    + [`addGMSpectrum`](/classes/transforms/wvtransformconstantstratification/addgmspectrum.html) add waves following a Garrett-Munk spectrum
    + [`addWaveModes`](/classes/transforms/wvtransformconstantstratification/addwavemodes.html) add amplitudes of the given wave modes
    + [`addWavesWithFrequencySpectrum`](/classes/transforms/wvtransformconstantstratification/addwaveswithfrequencyspectrum.html) add waves with a specified frequency spectrum
    + [`initWavesWithFrequencySpectrum`](/classes/transforms/wvtransformconstantstratification/initwaveswithfrequencyspectrum.html) initialize with waves of a specified frequency spectrum
    + [`initWithAlternativeSpectrum`](/classes/transforms/wvtransformconstantstratification/initwithalternativespectrum.html) initialize with an alternative formulation of the GM spectrum in the wavenumber domain.
    + [`initWithGMSpectrum`](/classes/transforms/wvtransformconstantstratification/initwithgmspectrum.html) initialize the wave field following a Garrett-Munk spectrum
    + [`initWithWaveModes`](/classes/transforms/wvtransformconstantstratification/initwithwavemodes.html) initialize with the given wave modes
    + [`removeAllWaves`](/classes/transforms/wvtransformconstantstratification/removeallwaves.html) removes all wave from the model, including inertial oscillations
    + [`setWaveModes`](/classes/transforms/wvtransformconstantstratification/setwavemodes.html) set amplitudes of the given wave modes
  + Geostrophic Motions
    + [`initWithGeostrophicStreamfunction`](/classes/transforms/wvtransformconstantstratification/initwithgeostrophicstreamfunction.html) initialize with a geostrophic streamfunction
    + [`setGeostrophicStreamfunction`](/classes/transforms/wvtransformconstantstratification/setgeostrophicstreamfunction.html) set a geostrophic streamfunction
    + [`addGeostrophicStreamfunction`](/classes/transforms/wvtransformconstantstratification/addgeostrophicstreamfunction.html) add a geostrophic streamfunction to existing geostrophic motions
    + [`setGeostrophicModes`](/classes/transforms/wvtransformconstantstratification/setgeostrophicmodes.html) set amplitudes of the given geostrophic modes
    + [`addGeostrophicModes`](/classes/transforms/wvtransformconstantstratification/addgeostrophicmodes.html) add amplitudes of the given geostrophic modes
    + [`removeAllGeostrophicMotions`](/classes/transforms/wvtransformconstantstratification/removeallgeostrophicmotions.html) remove all geostrophic motions
  + Inertial Oscillations
    + [`addInertialMotions`](/classes/transforms/wvtransformconstantstratification/addinertialmotions.html) add inertial motions to existing inertial motions
    + [`initWithInertialMotions`](/classes/transforms/wvtransformconstantstratification/initwithinertialmotions.html) initialize with inertial motions
    + [`removeAllInertialMotions`](/classes/transforms/wvtransformconstantstratification/removeallinertialmotions.html) remove all inertial motions
    + [`setInertialMotions`](/classes/transforms/wvtransformconstantstratification/setinertialmotions.html) set inertial motions
  + Mean density anomaly
    + [`addMeanDensityAnomaly`](/classes/transforms/wvtransformconstantstratification/addmeandensityanomaly.html) add inertial motions to existing inertial motions
    + [`initWithMeanDensityAnomaly`](/classes/transforms/wvtransformconstantstratification/initwithmeandensityanomaly.html) initialize with inertial motions
    + [`removeAllMeanDensityAnomaly`](/classes/transforms/wvtransformconstantstratification/removeallmeandensityanomaly.html) remove all mean density anomalies
    + [`setMeanDensityAnomaly`](/classes/transforms/wvtransformconstantstratification/setmeandensityanomaly.html) set inertial motions
+ Energetics of flow components
  + [`geostrophicEnergy`](/classes/transforms/wvtransformconstantstratification/geostrophicenergy.html) total energy, geostrophic
+ Operations
  + Transformations
    + [`FwInvMatrix`](/classes/transforms/wvtransformconstantstratification/fwinvmatrix.html) transformation matrix $$F_w^{-1}$$
    + [`FwMatrix`](/classes/transforms/wvtransformconstantstratification/fwmatrix.html) transformation matrix $$F_w$$
    + [`GwInvMatrix`](/classes/transforms/wvtransformconstantstratification/gwinvmatrix.html) transformation matrix $$G_w^{-1}$$
    + [`GwMatrix`](/classes/transforms/wvtransformconstantstratification/gwmatrix.html) transformation matrix $$G_w$$
    + [`transformToKLAxes`](/classes/transforms/wvtransformconstantstratification/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
    + [`transformToRadialWavenumber`](/classes/transforms/wvtransformconstantstratification/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
    + [`transformUVWEtaToWaveVortex`](/classes/transforms/wvtransformconstantstratification/transformuvwetatowavevortex.html) transform momentum variables $$(u,v,w,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
  + Grid transformation
    + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformconstantstratification/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
    + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformconstantstratification/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
  + Fourier transformation
    + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformconstantstratification/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
    + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformconstantstratification/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
    + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformconstantstratification/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
+ Wave-vortex coefficients
  + at time $$t$$
    + [`A0t`](/classes/transforms/wvtransformconstantstratification/a0t.html) geostrophic coefficients time t
    + [`Amt`](/classes/transforms/wvtransformconstantstratification/amt.html) negative wave coefficients at reference time t
    + [`Apt`](/classes/transforms/wvtransformconstantstratification/apt.html) positive wave coefficients at reference time t
+ Domain Attributes
  + [`f`](/classes/transforms/wvtransformconstantstratification/f.html) Coriolis parameter
  + [`g`](/classes/transforms/wvtransformconstantstratification/g.html) gravity of Earth
  + [`inertialPeriod`](/classes/transforms/wvtransformconstantstratification/inertialperiod.html) inertial period
  + [`latitude`](/classes/transforms/wvtransformconstantstratification/latitude.html) central latitude of the simulation
  + [`planetaryRadius`](/classes/transforms/wvtransformconstantstratification/planetaryradius.html) radius of the planetary body
  + [`rho0`](/classes/transforms/wvtransformconstantstratification/rho0.html) , dLnN2
  + [`rotationRate`](/classes/transforms/wvtransformconstantstratification/rotationrate.html) rotation rate of the planetary body
  + Grid
    + Spectral
      + [`J`](/classes/transforms/wvtransformconstantstratification/j_.html) j-coordinate matrix
      + [`K`](/classes/transforms/wvtransformconstantstratification/k_.html) k-coordinate matrix
      + [`K2`](/classes/transforms/wvtransformconstantstratification/k2.html) squared horizontal wavenumber, $$K2=K^2+L^2$$
      + [`Kh`](/classes/transforms/wvtransformconstantstratification/kh.html) horizontal wavenumber, $$Kh=\sqrt(K^2+L^2)$$
      + [`L`](/classes/transforms/wvtransformconstantstratification/l_.html) l-coordinate matrix
      + [`Nj`](/classes/transforms/wvtransformconstantstratification/nj.html) points in the j-coordinate, `length(z)`
    + Spatial
      + [`Nz`](/classes/transforms/wvtransformconstantstratification/nz.html) points in the third, untransformed, dimension
      + [`X`](/classes/transforms/wvtransformconstantstratification/x_.html) x-coordinate matrix
      + [`Y`](/classes/transforms/wvtransformconstantstratification/y_.html) y-coordinate matrix
      + [`Z`](/classes/transforms/wvtransformconstantstratification/z_.html) z-coordinate matrix
  + Spatial grid
    + [`x`](/classes/transforms/wvtransformconstantstratification/x.html) dimension
    + [`y`](/classes/transforms/wvtransformconstantstratification/y.html) dimension
    + [`Lx`](/classes/transforms/wvtransformconstantstratification/lx.html) length of the x-dimension
    + [`Ly`](/classes/transforms/wvtransformconstantstratification/ly.html) length of the y-dimension
    + [`Lz`](/classes/transforms/wvtransformconstantstratification/lz.html) length of the z-dimension
    + [`Nx`](/classes/transforms/wvtransformconstantstratification/nx.html) number of grid points in the x-dimension
    + [`Ny`](/classes/transforms/wvtransformconstantstratification/ny.html) number of grid points in the y-dimension
    + [`fastTransform`](/classes/transforms/wvtransformconstantstratification/fasttransform.html) fast transform object
  + DFT grid
    + [`Nk_dft`](/classes/transforms/wvtransformconstantstratification/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
    + [`Nl_dft`](/classes/transforms/wvtransformconstantstratification/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
    + [`conjugateDimension`](/classes/transforms/wvtransformconstantstratification/conjugatedimension.html) assumed conjugate dimension
    + [`kMode_dft`](/classes/transforms/wvtransformconstantstratification/kmode_dft.html) k mode-number on the DFT grid
    + [`k_dft`](/classes/transforms/wvtransformconstantstratification/k_dft.html) k wavenumber dimension on the DFT grid
    + [`lMode_dft`](/classes/transforms/wvtransformconstantstratification/lmode_dft.html) l mode-number on the DFT grid
    + [`l_dft`](/classes/transforms/wvtransformconstantstratification/l_dft.html) l wavenumber dimension on the DFT grid
  + WV grid
    + [`Nkl`](/classes/transforms/wvtransformconstantstratification/nkl.html) length of the combined kl-wavenumber dimension on the WV grid
    + [`dftConjugateIndex`](/classes/transforms/wvtransformconstantstratification/dftconjugateindex.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftConjugateIndices2D`](/classes/transforms/wvtransformconstantstratification/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftPrimaryIndex`](/classes/transforms/wvtransformconstantstratification/dftprimaryindex.html) index into the DFT grid of each WV mode
    + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformconstantstratification/dftprimaryindices2d.html) index into the DFT grid of each WV mode
    + [`dk`](/classes/transforms/wvtransformconstantstratification/dk.html) wavenumber spacing of the $$k$$ axis
    + [`dl`](/classes/transforms/wvtransformconstantstratification/dl.html) wavenumber spacing of the $$l$$ axis
    + [`k`](/classes/transforms/wvtransformconstantstratification/k.html) wavenumber dimension on the WV grid
    + [`kMode_wv`](/classes/transforms/wvtransformconstantstratification/kmode_wv.html) k mode number on the WV grid
    + [`kRadial`](/classes/transforms/wvtransformconstantstratification/kradial.html) radial (k,l) wavenumber on the WV grid
    + [`kl`](/classes/transforms/wvtransformconstantstratification/kl.html) wavenumber dimension
    + [`l`](/classes/transforms/wvtransformconstantstratification/l.html) wavenumber dimension on the WV grid
    + [`lMode_wv`](/classes/transforms/wvtransformconstantstratification/lmode_wv.html) l mode number on the WV grid
    + [`shouldAntialias`](/classes/transforms/wvtransformconstantstratification/shouldantialias.html) whether the WV grid includes quadratically aliased wavenumbers
    + [`shouldExcludeNyquist`](/classes/transforms/wvtransformconstantstratification/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
    + [`shouldExludeConjugates`](/classes/transforms/wvtransformconstantstratification/shouldexludeconjugates.html) whether the WV grid includes wavenumbers that are Hermitian conjugates
    + [`wvConjugateIndex`](/classes/transforms/wvtransformconstantstratification/wvconjugateindex.html) index into the WV mode that matches the dftConjugateIndices
  + Stratification
    + [`h_0`](/classes/transforms/wvtransformconstantstratification/h_0.html) equivalent depth of each geostrophic mode
+ Utility function
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformconstantstratification/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformconstantstratification/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformconstantstratification/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isHermitian`](/classes/transforms/wvtransformconstantstratification/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`setConjugateToUnity`](/classes/transforms/wvtransformconstantstratification/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
+ Properties
  + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformconstantstratification/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
+ Energetics
  + [`inertialEnergy`](/classes/transforms/wvtransformconstantstratification/inertialenergy.html) total energy of the inertial flow
  + [`mdaEnergy`](/classes/transforms/wvtransformconstantstratification/mdaenergy.html) total energy of the mean density anomaly
  + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformconstantstratification/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
  + [`waveEnergy`](/classes/transforms/wvtransformconstantstratification/waveenergy.html) total energy of the geostrophic flow
  + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformconstantstratification/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
+ Index gymnastics
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
  + [`klModeNumberFromIndex`](/classes/transforms/wvtransformconstantstratification/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
  + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformconstantstratification/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
+ Masks
  + [`maskForAliasedModes`](/classes/transforms/wvtransformconstantstratification/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
  + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformconstantstratification/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
  + [`maskForNyquistModes`](/classes/transforms/wvtransformconstantstratification/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
+ Utilities
  + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformconstantstratification/placeparticlesonisopycnal.html) places Lagrangian particles along a specified isopycnal
+ Developer
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformconstantstratification/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
+ State Variables
  + [`psi`](/classes/transforms/wvtransformconstantstratification/psi.html) geostrophic streamfunction
  + [`ssu`](/classes/transforms/wvtransformconstantstratification/ssu.html) x-component of the fluid velocity at the surface
  + [`ssv`](/classes/transforms/wvtransformconstantstratification/ssv.html) y-component of the fluid velocity at the surface
+ Potential Vorticity & Enstrophy
  + [`qgpv`](/classes/transforms/wvtransformconstantstratification/qgpv.html) quasigeostrophic potential vorticity
+ Internal
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformconstantstratification/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformconstantstratification/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors
+ Other
  + [`A0N`](/classes/transforms/wvtransformconstantstratification/a0n.html) matrix component that multiplies $$\tilde{\eta}$$ to compute $$A_0$$.
  + [`A0U`](/classes/transforms/wvtransformconstantstratification/a0u.html) matrix component that multiplies $$\tilde{u}$$ to compute $$A_0$$.
  + [`A0V`](/classes/transforms/wvtransformconstantstratification/a0v.html) matrix component that multiplies $$\tilde{v}$$ to compute $$A_0$$.
  + [`A0Z`](/classes/transforms/wvtransformconstantstratification/a0z.html) 
  + [`ApmD`](/classes/transforms/wvtransformconstantstratification/apmd.html) 
  + [`ApmD_scaled`](/classes/transforms/wvtransformconstantstratification/apmd_scaled.html) 
  + [`ApmN`](/classes/transforms/wvtransformconstantstratification/apmn.html) 
  + [`ApmW_scaled`](/classes/transforms/wvtransformconstantstratification/apmw_scaled.html) 
  + [`CosineTransformBackMatrix`](/classes/transforms/wvtransformconstantstratification/cosinetransformbackmatrix.html) Discrete Cosine Transform (DCT-I) matrix
  + [`CosineTransformForwardMatrix`](/classes/transforms/wvtransformconstantstratification/cosinetransformforwardmatrix.html) Discrete Cosine Transform (DCT-I) matrix
  + [`DCT`](/classes/transforms/wvtransformconstantstratification/dct.html) 
  + [`DST`](/classes/transforms/wvtransformconstantstratification/dst.html) 
  + [`F_g`](/classes/transforms/wvtransformconstantstratification/f_g.html) 
  + [`F_wg`](/classes/transforms/wvtransformconstantstratification/f_wg.html) 
  + [`Feta`](/classes/transforms/wvtransformconstantstratification/feta.html) 
  + [`Fu`](/classes/transforms/wvtransformconstantstratification/fu.html) 
  + [`Fv`](/classes/transforms/wvtransformconstantstratification/fv.html) 
  + [`G_g`](/classes/transforms/wvtransformconstantstratification/g_g.html) 
  + [`G_wg`](/classes/transforms/wvtransformconstantstratification/g_wg.html) 
  + [`Lr2`](/classes/transforms/wvtransformconstantstratification/lr2.html) squared Rossby radius
  + [`N0`](/classes/transforms/wvtransformconstantstratification/n0.html) buoyancy frequency of the no-motion density
  + [`N2Function`](/classes/transforms/wvtransformconstantstratification/n2function.html) takes $$z$$ values and returns the squared buoyancy frequency of the no-motion density.
  + [`NA0`](/classes/transforms/wvtransformconstantstratification/na0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{\eta}$$.
  + [`NAm`](/classes/transforms/wvtransformconstantstratification/nam.html) 
  + [`NAp`](/classes/transforms/wvtransformconstantstratification/nap.html) 
  + [`Omega`](/classes/transforms/wvtransformconstantstratification/omega.html) 
  + [`PA0`](/classes/transforms/wvtransformconstantstratification/pa0.html) 
  + [`SineTransformBackMatrix`](/classes/transforms/wvtransformconstantstratification/sinetransformbackmatrix.html) CosineTransformBackMatrix  Discrete Cosine Transform (DCT-I) matrix
  + [`SineTransformForwardMatrix`](/classes/transforms/wvtransformconstantstratification/sinetransformforwardmatrix.html) CosineTransformForwardMatrix  Discrete Cosine Transform (DCT-I) matrix
  + [`UA0`](/classes/transforms/wvtransformconstantstratification/ua0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{u}$$.
  + [`UAm`](/classes/transforms/wvtransformconstantstratification/uam.html) 
  + [`UAp`](/classes/transforms/wvtransformconstantstratification/uap.html) 
  + [`VA0`](/classes/transforms/wvtransformconstantstratification/va0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{v}$$.
  + [`VAm`](/classes/transforms/wvtransformconstantstratification/vam.html) 
  + [`VAp`](/classes/transforms/wvtransformconstantstratification/vap.html) 
  + [`WAm`](/classes/transforms/wvtransformconstantstratification/wam.html) 
  + [`WAp`](/classes/transforms/wvtransformconstantstratification/wap.html) 
  + [`beta`](/classes/transforms/wvtransformconstantstratification/beta.html) 
  + [`buildVerticalModeProjectionOperators`](/classes/transforms/wvtransformconstantstratification/buildverticalmodeprojectionoperators.html) Build the transformation matrices
  + [`buoyancyPeriod`](/classes/transforms/wvtransformconstantstratification/buoyancyperiod.html) 
  + [`chebfunForZArray`](/classes/transforms/wvtransformconstantstratification/chebfunforzarray.html) 
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformconstantstratification/classrequiredpropertynames.html) 
  + [`conjPhase`](/classes/transforms/wvtransformconstantstratification/conjphase.html) phase of the Am wave modes
  + [`cos_alpha`](/classes/transforms/wvtransformconstantstratification/cos_alpha.html) 
  + [`diffX`](/classes/transforms/wvtransformconstantstratification/diffx.html) 
  + [`diffY`](/classes/transforms/wvtransformconstantstratification/diffy.html) 
  + [`diffZF`](/classes/transforms/wvtransformconstantstratification/diffzf.html) 
  + [`diffZG`](/classes/transforms/wvtransformconstantstratification/diffzg.html) 
  + [`effectiveJMax`](/classes/transforms/wvtransformconstantstratification/effectivejmax.html) 
  + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformconstantstratification/enstrophyfluxfromf0.html) 
  + [`eta`](/classes/transforms/wvtransformconstantstratification/eta.html) approximate isopycnal deviation
  + [`geometryFromFile`](/classes/transforms/wvtransformconstantstratification/geometryfromfile.html) 
  + [`geometryFromGroup`](/classes/transforms/wvtransformconstantstratification/geometryfromgroup.html) 
  + [`h_pm`](/classes/transforms/wvtransformconstantstratification/h_pm.html) 
  + [`iDCT`](/classes/transforms/wvtransformconstantstratification/idct.html) 
  + [`iDST`](/classes/transforms/wvtransformconstantstratification/idst.html) 
  + [`iOmega`](/classes/transforms/wvtransformconstantstratification/iomega.html) 
  + [`intZF`](/classes/transforms/wvtransformconstantstratification/intzf.html)
  + [`intZG`](/classes/transforms/wvtransformconstantstratification/intzg.html)
  + [`j`](/classes/transforms/wvtransformconstantstratification/j.html) vertical mode number
  + [`kAxis`](/classes/transforms/wvtransformconstantstratification/kaxis.html) k coordinate
  + [`kljGrid`](/classes/transforms/wvtransformconstantstratification/kljgrid.html) 
  + [`lAxis`](/classes/transforms/wvtransformconstantstratification/laxis.html) l coordinate
  + [`maxFg`](/classes/transforms/wvtransformconstantstratification/maxfg.html) 
  + [`maxFw`](/classes/transforms/wvtransformconstantstratification/maxfw.html) 
  + [`modeNumberFromIndex`](/classes/transforms/wvtransformconstantstratification/modenumberfromindex.html) 
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformconstantstratification/namesofrequiredpropertiesforgeometry.html) 
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformconstantstratification/namesofrequiredpropertiesforrotatingfplane.html) 
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformconstantstratification/namesofrequiredpropertiesfortransform.html) 
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformconstantstratification/namesoftransformvariables.html) 
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformconstantstratification/newnonrequiredpropertynames.html) 
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformconstantstratification/newrequiredpropertynames.html) 
  + [`nonlinearFluxFunction`](/classes/transforms/wvtransformconstantstratification/nonlinearfluxfunction.html) 
  + [`nonlinearFluxHydrostatic`](/classes/transforms/wvtransformconstantstratification/nonlinearfluxhydrostatic.html) 
  + [`nonlinearFluxNonhydrostatic`](/classes/transforms/wvtransformconstantstratification/nonlinearfluxnonhydrostatic.html) 
  + [`p`](/classes/transforms/wvtransformconstantstratification/p.html) pressure anomaly
  + [`phase`](/classes/transforms/wvtransformconstantstratification/phase.html) phase of the Ap wave modes
  + [`pi`](/classes/transforms/wvtransformconstantstratification/pi.html) height anomaly
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformconstantstratification/propertyannotationsforrotatingfplane.html) 
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformconstantstratification/qgpvfluxfromf0.html) 
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformconstantstratification/requiredpropertiesforgeometryfromgroup.html) 
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformconstantstratification/requiredpropertiesforrotatingfplanefromgroup.html) 
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformconstantstratification/requiredpropertiesfortransformfromgroup.html) 
  + [`rhoFunction`](/classes/transforms/wvtransformconstantstratification/rhofunction.html) eta_true operation needs rhoFunction
  + [`rho_e`](/classes/transforms/wvtransformconstantstratification/rho_e.html) excess density
  + [`rho_nm0`](/classes/transforms/wvtransformconstantstratification/rho_nm0.html) $$\rho_\textrm{nm}(z)$$, no-motion density at time `t0`
  + [`rho_total`](/classes/transforms/wvtransformconstantstratification/rho_total.html) total potential density
  + [`shouldUseTrueNoMotionProfile`](/classes/transforms/wvtransformconstantstratification/shouldusetruenomotionprofile.html) whether eta_true uses rho_nm instead of rho_nm0
  + [`sin_alpha`](/classes/transforms/wvtransformconstantstratification/sin_alpha.html) 
  + [`spatialFluxForForcingWithName`](/classes/transforms/wvtransformconstantstratification/spatialfluxforforcingwithname.html) 
  + [`spatialMatrixSize`](/classes/transforms/wvtransformconstantstratification/spatialmatrixsize.html) 
  + [`spectralMatrixSize`](/classes/transforms/wvtransformconstantstratification/spectralmatrixsize.html) 
  + [`ssh`](/classes/transforms/wvtransformconstantstratification/ssh.html) sea-surface height
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformconstantstratification/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`totalEnstrophy`](/classes/transforms/wvtransformconstantstratification/totalenstrophy.html) 
  + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformconstantstratification/totalenstrophyspatiallyintegrated.html) 
  + [`transformFromGroup`](/classes/transforms/wvtransformconstantstratification/transformfromgroup.html) 
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformconstantstratification/transformfromspatialdomainwithfio.html) 
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformconstantstratification/transformfromspatialdomainwithfourier.html) 
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformconstantstratification/transformtospatialdomainwithfourier.html) 
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformconstantstratification/transformtospatialdomainwithfourieratposition.html) 
  + [`transformWithG_wg`](/classes/transforms/wvtransformconstantstratification/transformwithg_wg.html) 
  + [`u`](/classes/transforms/wvtransformconstantstratification/u.html) x-component of the fluid velocity
  + [`uvMax`](/classes/transforms/wvtransformconstantstratification/uvmax.html) max horizontal fluid speed
  + [`v`](/classes/transforms/wvtransformconstantstratification/v.html) y-component of the fluid velocity
  + [`verticalModes`](/classes/transforms/wvtransformconstantstratification/verticalmodes.html) 
  + [`verticalProjectionOperatorsWithFreeSurface`](/classes/transforms/wvtransformconstantstratification/verticalprojectionoperatorswithfreesurface.html) 
  + [`w`](/classes/transforms/wvtransformconstantstratification/w.html) z-component of the fluid velocity
  + [`wMax`](/classes/transforms/wvtransformconstantstratification/wmax.html) max vertical fluid speed
  + [`waveCoefficientsAtTimeT`](/classes/transforms/wvtransformconstantstratification/wavecoefficientsattimet.html) 
  + [`waveVortexTransformWithExplicitAntialiasing`](/classes/transforms/wvtransformconstantstratification/wavevortextransformwithexplicitantialiasing.html) 
  + [`xyzGrid`](/classes/transforms/wvtransformconstantstratification/xyzgrid.html) 
  + [`z`](/classes/transforms/wvtransformconstantstratification/z.html) z coordinate
  + [`z_int`](/classes/transforms/wvtransformconstantstratification/z_int.html) Quadrature weights for the vertical grid
  + [`zeta_z`](/classes/transforms/wvtransformconstantstratification/zeta_z.html) vertical component of relative vorticity


---
