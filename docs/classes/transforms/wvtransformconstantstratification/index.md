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
  + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformconstantstratification/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
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
+ Domain attributes
  + Spatial grid
    + [`Lx`](/classes/transforms/wvtransformconstantstratification/lx.html) length of the x-dimension
    + [`Ly`](/classes/transforms/wvtransformconstantstratification/ly.html) length of the y-dimension
    + [`Lz`](/classes/transforms/wvtransformconstantstratification/lz.html) length of the z-dimension
    + [`Nx`](/classes/transforms/wvtransformconstantstratification/nx.html) number of grid points in the x-dimension
    + [`Ny`](/classes/transforms/wvtransformconstantstratification/ny.html) number of grid points in the y-dimension
    + [`fastTransform`](/classes/transforms/wvtransformconstantstratification/fasttransform.html) fast transform object
    + [`x`](/classes/transforms/wvtransformconstantstratification/x.html) dimension
    + [`y`](/classes/transforms/wvtransformconstantstratification/y.html) dimension
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
+ Utility function
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformconstantstratification/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformconstantstratification/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformconstantstratification/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isHermitian`](/classes/transforms/wvtransformconstantstratification/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`setConjugateToUnity`](/classes/transforms/wvtransformconstantstratification/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
+ Properties
  + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformconstantstratification/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
+ Energetics
  + [`geostrophicEnergy`](/classes/transforms/wvtransformconstantstratification/geostrophicenergy.html) total energy of the geostrophic flow
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
+ Developer
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformconstantstratification/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
+ Internal
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformconstantstratification/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformconstantstratification/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors
+ Other
  + [`A0N`](/classes/transforms/wvtransformconstantstratification/a0n.html) 
  + [`A0Z`](/classes/transforms/wvtransformconstantstratification/a0z.html) 
  + [`ApmD`](/classes/transforms/wvtransformconstantstratification/apmd.html) 
  + [`ApmD_scaled`](/classes/transforms/wvtransformconstantstratification/apmd_scaled.html) 
  + [`ApmN`](/classes/transforms/wvtransformconstantstratification/apmn.html) 
  + [`ApmW_scaled`](/classes/transforms/wvtransformconstantstratification/apmw_scaled.html) 
  + [`CosineTransformBackMatrix`](/classes/transforms/wvtransformconstantstratification/cosinetransformbackmatrix.html) Discrete Cosine Transform (DCT-I) matrix
  + [`CosineTransformForwardMatrix`](/classes/transforms/wvtransformconstantstratification/cosinetransformforwardmatrix.html) Discrete Cosine Transform (DCT-I) matrix
  + [`DCT`](/classes/transforms/wvtransformconstantstratification/dct.html) 
  + [`DST`](/classes/transforms/wvtransformconstantstratification/dst.html) 
  + [`FMatrix`](/classes/transforms/wvtransformconstantstratification/fmatrix.html) 
  + [`F_g`](/classes/transforms/wvtransformconstantstratification/f_g.html) 
  + [`F_wg`](/classes/transforms/wvtransformconstantstratification/f_wg.html) 
  + [`Feta`](/classes/transforms/wvtransformconstantstratification/feta.html) 
  + [`FinvMatrix`](/classes/transforms/wvtransformconstantstratification/finvmatrix.html) 
  + [`Fu`](/classes/transforms/wvtransformconstantstratification/fu.html) 
  + [`Fv`](/classes/transforms/wvtransformconstantstratification/fv.html) 
  + [`GMatrix`](/classes/transforms/wvtransformconstantstratification/gmatrix.html) 
  + [`G_g`](/classes/transforms/wvtransformconstantstratification/g_g.html) 
  + [`G_wg`](/classes/transforms/wvtransformconstantstratification/g_wg.html) 
  + [`GinvMatrix`](/classes/transforms/wvtransformconstantstratification/ginvmatrix.html) 
  + [`J`](/classes/transforms/wvtransformconstantstratification/j_.html) 
  + [`K`](/classes/transforms/wvtransformconstantstratification/k_.html) 
  + [`K2`](/classes/transforms/wvtransformconstantstratification/k2.html) 
  + [`Kh`](/classes/transforms/wvtransformconstantstratification/kh.html) 
  + [`L`](/classes/transforms/wvtransformconstantstratification/l_.html) 
  + [`Lr2`](/classes/transforms/wvtransformconstantstratification/lr2.html) 
  + [`N0`](/classes/transforms/wvtransformconstantstratification/n0.html) 
  + [`N2`](/classes/transforms/wvtransformconstantstratification/n2.html) 
  + [`N2Function`](/classes/transforms/wvtransformconstantstratification/n2function.html) 
  + [`NA0`](/classes/transforms/wvtransformconstantstratification/na0.html) 
  + [`NAm`](/classes/transforms/wvtransformconstantstratification/nam.html) 
  + [`NAp`](/classes/transforms/wvtransformconstantstratification/nap.html) 
  + [`Nj`](/classes/transforms/wvtransformconstantstratification/nj.html) 
  + [`Nz`](/classes/transforms/wvtransformconstantstratification/nz.html) 
  + [`Omega`](/classes/transforms/wvtransformconstantstratification/omega.html) 
  + [`PA0`](/classes/transforms/wvtransformconstantstratification/pa0.html) 
  + [`SineTransformBackMatrix`](/classes/transforms/wvtransformconstantstratification/sinetransformbackmatrix.html) CosineTransformBackMatrix  Discrete Cosine Transform (DCT-I) matrix
  + [`SineTransformForwardMatrix`](/classes/transforms/wvtransformconstantstratification/sinetransformforwardmatrix.html) CosineTransformForwardMatrix  Discrete Cosine Transform (DCT-I) matrix
  + [`UA0`](/classes/transforms/wvtransformconstantstratification/ua0.html) 
  + [`UAm`](/classes/transforms/wvtransformconstantstratification/uam.html) 
  + [`UAp`](/classes/transforms/wvtransformconstantstratification/uap.html) 
  + [`VA0`](/classes/transforms/wvtransformconstantstratification/va0.html) 
  + [`VAm`](/classes/transforms/wvtransformconstantstratification/vam.html) 
  + [`VAp`](/classes/transforms/wvtransformconstantstratification/vap.html) 
  + [`WAm`](/classes/transforms/wvtransformconstantstratification/wam.html) 
  + [`WAp`](/classes/transforms/wvtransformconstantstratification/wap.html) 
  + [`X`](/classes/transforms/wvtransformconstantstratification/x_.html) 
  + [`Y`](/classes/transforms/wvtransformconstantstratification/y_.html) 
  + [`Z`](/classes/transforms/wvtransformconstantstratification/z_.html) 
  + [`beta`](/classes/transforms/wvtransformconstantstratification/beta.html) 
  + [`buildVerticalModeProjectionOperators`](/classes/transforms/wvtransformconstantstratification/buildverticalmodeprojectionoperators.html) Build the transformation matrices
  + [`chebfunForZArray`](/classes/transforms/wvtransformconstantstratification/chebfunforzarray.html) 
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformconstantstratification/classrequiredpropertynames.html) 
  + [`cos_alpha`](/classes/transforms/wvtransformconstantstratification/cos_alpha.html) 
  + [`diffX`](/classes/transforms/wvtransformconstantstratification/diffx.html) 
  + [`diffY`](/classes/transforms/wvtransformconstantstratification/diffy.html) 
  + [`diffZF`](/classes/transforms/wvtransformconstantstratification/diffzf.html) 
  + [`diffZG`](/classes/transforms/wvtransformconstantstratification/diffzg.html) 
  + [`effectiveJMax`](/classes/transforms/wvtransformconstantstratification/effectivejmax.html) 
  + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformconstantstratification/enstrophyfluxfromf0.html) 
  + [`f`](/classes/transforms/wvtransformconstantstratification/f.html) 
  + [`g`](/classes/transforms/wvtransformconstantstratification/g.html) 
  + [`geometryFromFile`](/classes/transforms/wvtransformconstantstratification/geometryfromfile.html) 
  + [`geometryFromGroup`](/classes/transforms/wvtransformconstantstratification/geometryfromgroup.html) 
  + [`h_0`](/classes/transforms/wvtransformconstantstratification/h_0.html) 
  + [`h_pm`](/classes/transforms/wvtransformconstantstratification/h_pm.html) 
  + [`iDCT`](/classes/transforms/wvtransformconstantstratification/idct.html) 
  + [`iDST`](/classes/transforms/wvtransformconstantstratification/idst.html) 
  + [`iOmega`](/classes/transforms/wvtransformconstantstratification/iomega.html) 
  + [`inertialPeriod`](/classes/transforms/wvtransformconstantstratification/inertialperiod.html) 
  + [`j`](/classes/transforms/wvtransformconstantstratification/j.html) 
  + [`kAxis`](/classes/transforms/wvtransformconstantstratification/kaxis.html) 
  + [`kljGrid`](/classes/transforms/wvtransformconstantstratification/kljgrid.html) 
  + [`lAxis`](/classes/transforms/wvtransformconstantstratification/laxis.html) 
  + [`latitude`](/classes/transforms/wvtransformconstantstratification/latitude.html) 
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
  + [`planetaryRadius`](/classes/transforms/wvtransformconstantstratification/planetaryradius.html) 
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformconstantstratification/propertyannotationsforrotatingfplane.html) 
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformconstantstratification/qgpvfluxfromf0.html) 
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformconstantstratification/requiredpropertiesforgeometryfromgroup.html) 
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformconstantstratification/requiredpropertiesforrotatingfplanefromgroup.html) 
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformconstantstratification/requiredpropertiesfortransformfromgroup.html) 
  + [`rho0`](/classes/transforms/wvtransformconstantstratification/rho0.html) , dLnN2
  + [`rhoFunction`](/classes/transforms/wvtransformconstantstratification/rhofunction.html) eta_true operation needs rhoFunction
  + [`rho_nm0`](/classes/transforms/wvtransformconstantstratification/rho_nm0.html) 
  + [`rotationRate`](/classes/transforms/wvtransformconstantstratification/rotationrate.html) 
  + [`sin_alpha`](/classes/transforms/wvtransformconstantstratification/sin_alpha.html) 
  + [`spatialFluxForForcingWithName`](/classes/transforms/wvtransformconstantstratification/spatialfluxforforcingwithname.html) 
  + [`spatialMatrixSize`](/classes/transforms/wvtransformconstantstratification/spatialmatrixsize.html) 
  + [`spectralMatrixSize`](/classes/transforms/wvtransformconstantstratification/spectralmatrixsize.html) 
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformconstantstratification/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`totalEnstrophy`](/classes/transforms/wvtransformconstantstratification/totalenstrophy.html) 
  + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformconstantstratification/totalenstrophyspatiallyintegrated.html) 
  + [`transformFromGroup`](/classes/transforms/wvtransformconstantstratification/transformfromgroup.html) 
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformconstantstratification/transformfromspatialdomainwithfio.html) 
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformconstantstratification/transformfromspatialdomainwithfourier.html) 
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformconstantstratification/transformtospatialdomainwithfourier.html) 
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformconstantstratification/transformtospatialdomainwithfourieratposition.html) 
  + [`transformWithG_wg`](/classes/transforms/wvtransformconstantstratification/transformwithg_wg.html) 
  + [`verticalModes`](/classes/transforms/wvtransformconstantstratification/verticalmodes.html) 
  + [`verticalProjectionOperatorsWithFreeSurface`](/classes/transforms/wvtransformconstantstratification/verticalprojectionoperatorswithfreesurface.html) 
  + [`waveCoefficientsAtTimeT`](/classes/transforms/wvtransformconstantstratification/wavecoefficientsattimet.html) 
  + [`waveVortexTransformWithExplicitAntialiasing`](/classes/transforms/wvtransformconstantstratification/wavevortextransformwithexplicitantialiasing.html) 
  + [`xyzGrid`](/classes/transforms/wvtransformconstantstratification/xyzgrid.html) 
  + [`z`](/classes/transforms/wvtransformconstantstratification/z.html) 
  + [`z_int`](/classes/transforms/wvtransformconstantstratification/z_int.html) 


---