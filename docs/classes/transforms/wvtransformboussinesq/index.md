---
layout: default
title: WVTransformBoussinesq
has_children: false
has_toc: false
mathjax: true
parent: Transforms
grand_parent: Class documentation
nav_order: 1
---

#  WVTransformBoussinesq

A class for disentangling hydrostatic waves and vortices in variable stratification


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransformHydrostatic < <a href="/classes/wvtransform/" title="WVTransform">WVTransform</a></code></pre></div></div>

## Overview
To initialization an instance of the WVTransformHydrostatic class you must specific the domain size, the number of grid points and *either* the density profile or the stratification profile.

  ```matlab
  N0 = 3*2*pi/3600;
  L_gm = 1300;
  N2 = @(z) N0*N0*exp(2*z/L_gm);
  wvt = WVTransformHydrostatic([100e3, 100e3, 4000],[64, 64, 65], N2=N2,latitude=30);
  ```


## Topics
+ Initialization
  + [`WVTransformBoussinesq`](/classes/transforms/wvtransformboussinesq/wvtransformboussinesq.html) create a wave-vortex transform for variable stratification
+ Primary flow components
  + [`geostrophicComponent`](/classes/transforms/wvtransformboussinesq/geostrophiccomponent.html) returns the geostrophic flow component
  + [`waveComponent`](/classes/transforms/wvtransformboussinesq/wavecomponent.html) returns the internal gravity wave flow component
  + [`inertialComponent`](/classes/transforms/wvtransformboussinesq/inertialcomponent.html) returns the inertial oscillation flow component
  + [`mdaComponent`](/classes/transforms/wvtransformboussinesq/mdacomponent.html) returns the mean density anomaly component
+ Stratification
  + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformboussinesq/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
  + Validation
    + [`isDensityInValidRange`](/classes/transforms/wvtransformboussinesq/isdensityinvalidrange.html) checks if the density field is a valid adiabatic re-arrangement of the base state
+ Initial conditions
  + Waves
    + [`addGMSpectrum`](/classes/transforms/wvtransformboussinesq/addgmspectrum.html) add waves following a Garrett-Munk spectrum
    + [`addWaveModes`](/classes/transforms/wvtransformboussinesq/addwavemodes.html) add amplitudes of the given wave modes
    + [`addWavesWithFrequencySpectrum`](/classes/transforms/wvtransformboussinesq/addwaveswithfrequencyspectrum.html) add waves with a specified frequency spectrum
    + [`initWavesWithFrequencySpectrum`](/classes/transforms/wvtransformboussinesq/initwaveswithfrequencyspectrum.html) initialize with waves of a specified frequency spectrum
    + [`initWithAlternativeSpectrum`](/classes/transforms/wvtransformboussinesq/initwithalternativespectrum.html) initialize with an alternative formulation of the GM spectrum in the wavenumber domain.
    + [`initWithGMSpectrum`](/classes/transforms/wvtransformboussinesq/initwithgmspectrum.html) initialize the wave field following a Garrett-Munk spectrum
    + [`initWithWaveModes`](/classes/transforms/wvtransformboussinesq/initwithwavemodes.html) initialize with the given wave modes
    + [`removeAllWaves`](/classes/transforms/wvtransformboussinesq/removeallwaves.html) removes all wave from the model, including inertial oscillations
    + [`setWaveModes`](/classes/transforms/wvtransformboussinesq/setwavemodes.html) set amplitudes of the given wave modes
  + Geostrophic Motions
    + [`initWithGeostrophicStreamfunction`](/classes/transforms/wvtransformboussinesq/initwithgeostrophicstreamfunction.html) initialize with a geostrophic streamfunction
    + [`setGeostrophicStreamfunction`](/classes/transforms/wvtransformboussinesq/setgeostrophicstreamfunction.html) set a geostrophic streamfunction
    + [`addGeostrophicStreamfunction`](/classes/transforms/wvtransformboussinesq/addgeostrophicstreamfunction.html) add a geostrophic streamfunction to existing geostrophic motions
    + [`setGeostrophicModes`](/classes/transforms/wvtransformboussinesq/setgeostrophicmodes.html) set amplitudes of the given geostrophic modes
    + [`addGeostrophicModes`](/classes/transforms/wvtransformboussinesq/addgeostrophicmodes.html) add amplitudes of the given geostrophic modes
    + [`removeAllGeostrophicMotions`](/classes/transforms/wvtransformboussinesq/removeallgeostrophicmotions.html) remove all geostrophic motions
  + Inertial Oscillations
    + [`addInertialMotions`](/classes/transforms/wvtransformboussinesq/addinertialmotions.html) add inertial motions to existing inertial motions
    + [`initWithInertialMotions`](/classes/transforms/wvtransformboussinesq/initwithinertialmotions.html) initialize with inertial motions
    + [`removeAllInertialMotions`](/classes/transforms/wvtransformboussinesq/removeallinertialmotions.html) remove all inertial motions
    + [`setInertialMotions`](/classes/transforms/wvtransformboussinesq/setinertialmotions.html) set inertial motions
  + Mean density anomaly
    + [`addMeanDensityAnomaly`](/classes/transforms/wvtransformboussinesq/addmeandensityanomaly.html) add inertial motions to existing inertial motions
    + [`initWithMeanDensityAnomaly`](/classes/transforms/wvtransformboussinesq/initwithmeandensityanomaly.html) initialize with inertial motions
    + [`removeAllMeanDensityAnomaly`](/classes/transforms/wvtransformboussinesq/removeallmeandensityanomaly.html) remove all mean density anomalies
    + [`setMeanDensityAnomaly`](/classes/transforms/wvtransformboussinesq/setmeandensityanomaly.html) set inertial motions
+ Operations
  + Transformations
    + [`FwInvMatrix`](/classes/transforms/wvtransformboussinesq/fwinvmatrix.html) transformation matrix $$F_w^{-1}$$
    + [`FwMatrix`](/classes/transforms/wvtransformboussinesq/fwmatrix.html) transformation matrix $$F_w$$
    + [`GwInvMatrix`](/classes/transforms/wvtransformboussinesq/gwinvmatrix.html) transformation matrix $$G_w^{-1}$$
    + [`GwMatrix`](/classes/transforms/wvtransformboussinesq/gwmatrix.html) transformation matrix $$G_w$$
    + [`transformToKLAxes`](/classes/transforms/wvtransformboussinesq/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
    + [`transformToOmegaAxis`](/classes/transforms/wvtransformboussinesq/transformtoomegaaxis.html) transforms in the from (j,kRadial) to omegaAxis
    + [`transformToPseudoRadialWavenumber`](/classes/transforms/wvtransformboussinesq/transformtopseudoradialwavenumber.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberA0`](/classes/transforms/wvtransformboussinesq/transformtopseudoradialwavenumbera0.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberApm`](/classes/transforms/wvtransformboussinesq/transformtopseudoradialwavenumberapm.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToRadialWavenumber`](/classes/transforms/wvtransformboussinesq/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
    + [`transformUVWEtaToWaveVortex`](/classes/transforms/wvtransformboussinesq/transformuvwetatowavevortex.html) transform momentum variables $$(u,v,w,\eta)$$ to wave-vortex coefficients $$(A_+,A_-,A_0)$$.
  + Grid transformation
    + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformboussinesq/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
    + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformboussinesq/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
  + Fourier transformation
    + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformboussinesq/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
    + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
    + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformboussinesq/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
+ Domain attributes
  + Spatial grid
    + [`Lx`](/classes/transforms/wvtransformboussinesq/lx.html) length of the x-dimension
    + [`Ly`](/classes/transforms/wvtransformboussinesq/ly.html) length of the y-dimension
    + [`Lz`](/classes/transforms/wvtransformboussinesq/lz.html) length of the z-dimension
    + [`Nx`](/classes/transforms/wvtransformboussinesq/nx.html) number of grid points in the x-dimension
    + [`Ny`](/classes/transforms/wvtransformboussinesq/ny.html) number of grid points in the y-dimension
    + [`fastTransform`](/classes/transforms/wvtransformboussinesq/fasttransform.html) fast transform object
    + [`x`](/classes/transforms/wvtransformboussinesq/x.html) dimension
    + [`y`](/classes/transforms/wvtransformboussinesq/y.html) dimension
  + DFT grid
    + [`Nk_dft`](/classes/transforms/wvtransformboussinesq/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
    + [`Nl_dft`](/classes/transforms/wvtransformboussinesq/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
    + [`conjugateDimension`](/classes/transforms/wvtransformboussinesq/conjugatedimension.html) assumed conjugate dimension
    + [`kMode_dft`](/classes/transforms/wvtransformboussinesq/kmode_dft.html) k mode-number on the DFT grid
    + [`k_dft`](/classes/transforms/wvtransformboussinesq/k_dft.html) k wavenumber dimension on the DFT grid
    + [`lMode_dft`](/classes/transforms/wvtransformboussinesq/lmode_dft.html) l mode-number on the DFT grid
    + [`l_dft`](/classes/transforms/wvtransformboussinesq/l_dft.html) l wavenumber dimension on the DFT grid
  + WV grid
    + [`Nkl`](/classes/transforms/wvtransformboussinesq/nkl.html) length of the combined kl-wavenumber dimension on the WV grid
    + [`dftConjugateIndex`](/classes/transforms/wvtransformboussinesq/dftconjugateindex.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftConjugateIndices2D`](/classes/transforms/wvtransformboussinesq/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftPrimaryIndex`](/classes/transforms/wvtransformboussinesq/dftprimaryindex.html) index into the DFT grid of each WV mode
    + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformboussinesq/dftprimaryindices2d.html) index into the DFT grid of each WV mode
    + [`dk`](/classes/transforms/wvtransformboussinesq/dk.html) wavenumber spacing of the $$k$$ axis
    + [`dl`](/classes/transforms/wvtransformboussinesq/dl.html) wavenumber spacing of the $$l$$ axis
    + [`k`](/classes/transforms/wvtransformboussinesq/k.html) wavenumber dimension on the WV grid
    + [`kMode_wv`](/classes/transforms/wvtransformboussinesq/kmode_wv.html) k mode number on the WV grid
    + [`kRadial`](/classes/transforms/wvtransformboussinesq/kradial.html) radial (k,l) wavenumber on the WV grid
    + [`kl`](/classes/transforms/wvtransformboussinesq/kl.html) wavenumber dimension
    + [`l`](/classes/transforms/wvtransformboussinesq/l.html) wavenumber dimension on the WV grid
    + [`lMode_wv`](/classes/transforms/wvtransformboussinesq/lmode_wv.html) l mode number on the WV grid
    + [`shouldAntialias`](/classes/transforms/wvtransformboussinesq/shouldantialias.html) whether the WV grid includes quadratically aliased wavenumbers
    + [`shouldExcludeNyquist`](/classes/transforms/wvtransformboussinesq/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
    + [`shouldExludeConjugates`](/classes/transforms/wvtransformboussinesq/shouldexludeconjugates.html) whether the WV grid includes wavenumbers that are Hermitian conjugates
    + [`wvConjugateIndex`](/classes/transforms/wvtransformboussinesq/wvconjugateindex.html) index into the WV mode that matches the dftConjugateIndices
+ Utility function
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformboussinesq/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformboussinesq/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformboussinesq/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isHermitian`](/classes/transforms/wvtransformboussinesq/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`setConjugateToUnity`](/classes/transforms/wvtransformboussinesq/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
+ Properties
  + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformboussinesq/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
+ Energetics
  + [`geostrophicEnergy`](/classes/transforms/wvtransformboussinesq/geostrophicenergy.html) total energy of the geostrophic flow
  + [`inertialEnergy`](/classes/transforms/wvtransformboussinesq/inertialenergy.html) total energy of the inertial flow
  + [`mdaEnergy`](/classes/transforms/wvtransformboussinesq/mdaenergy.html) total energy of the mean density anomaly
  + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformboussinesq/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
  + [`waveEnergy`](/classes/transforms/wvtransformboussinesq/waveenergy.html) total energy of the geostrophic flow
  + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformboussinesq/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
+ Index gymnastics
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
  + [`klModeNumberFromIndex`](/classes/transforms/wvtransformboussinesq/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
  + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformboussinesq/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
+ Masks
  + [`maskForAliasedModes`](/classes/transforms/wvtransformboussinesq/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
  + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformboussinesq/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
  + [`maskForNyquistModes`](/classes/transforms/wvtransformboussinesq/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
+ Developer
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformboussinesq/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
+ Internal
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformboussinesq/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformboussinesq/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors
+ Other
  + [`A0N`](/classes/transforms/wvtransformboussinesq/a0n.html) 
  + [`A0Z`](/classes/transforms/wvtransformboussinesq/a0z.html) 
  + [`ApmD`](/classes/transforms/wvtransformboussinesq/apmd.html) 
  + [`ApmN`](/classes/transforms/wvtransformboussinesq/apmn.html) 
  + [`ApmW`](/classes/transforms/wvtransformboussinesq/apmw.html) 
  + [`Ddelta`](/classes/transforms/wvtransformboussinesq/ddelta.html) 
  + [`FMatrix`](/classes/transforms/wvtransformboussinesq/fmatrix.html) 
  + [`Feta`](/classes/transforms/wvtransformboussinesq/feta.html) 
  + [`FinvMatrix`](/classes/transforms/wvtransformboussinesq/finvmatrix.html) 
  + [`Fu`](/classes/transforms/wvtransformboussinesq/fu.html) 
  + [`Fv`](/classes/transforms/wvtransformboussinesq/fv.html) 
  + [`GMatrix`](/classes/transforms/wvtransformboussinesq/gmatrix.html) 
  + [`GinvMatrix`](/classes/transforms/wvtransformboussinesq/ginvmatrix.html) 
  + [`J`](/classes/transforms/wvtransformboussinesq/j_.html) 
  + [`K`](/classes/transforms/wvtransformboussinesq/k_.html) 
  + [`K2`](/classes/transforms/wvtransformboussinesq/k2.html) 
  + [`K2unique`](/classes/transforms/wvtransformboussinesq/k2unique.html) unique squared-wavenumbers
  + [`K2uniqueK2Map`](/classes/transforms/wvtransformboussinesq/k2uniquek2map.html) cell array Nk in length. Each cell contains indices back to K2
  + [`Kh`](/classes/transforms/wvtransformboussinesq/kh.html) 
  + [`L`](/classes/transforms/wvtransformboussinesq/l_.html) 
  + [`Lr2`](/classes/transforms/wvtransformboussinesq/lr2.html) 
  + [`N2`](/classes/transforms/wvtransformboussinesq/n2.html) 
  + [`N2Function`](/classes/transforms/wvtransformboussinesq/n2function.html) 
  + [`NA0`](/classes/transforms/wvtransformboussinesq/na0.html) 
  + [`NAm`](/classes/transforms/wvtransformboussinesq/nam.html) 
  + [`NAp`](/classes/transforms/wvtransformboussinesq/nap.html) 
  + [`Nj`](/classes/transforms/wvtransformboussinesq/nj.html) 
  + [`Nz`](/classes/transforms/wvtransformboussinesq/nz.html) 
  + [`Omega`](/classes/transforms/wvtransformboussinesq/omega.html) 
  + [`P0`](/classes/transforms/wvtransformboussinesq/p0.html) Preconditioner for F, size(P)=[Nj 1]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`PA0`](/classes/transforms/wvtransformboussinesq/pa0.html) 
  + [`PF0`](/classes/transforms/wvtransformboussinesq/pf0.html) size(PF,PG)=[Nj x Nz]
  + [`PF0inv`](/classes/transforms/wvtransformboussinesq/pf0inv.html) Transformation matrices
  + [`PFpm`](/classes/transforms/wvtransformboussinesq/pfpm.html) size(PF,PG)=[Nj x Nz x Nk]
  + [`PFpmInv`](/classes/transforms/wvtransformboussinesq/pfpminv.html) IGW transformation matrices
  + [`Ppm`](/classes/transforms/wvtransformboussinesq/ppm.html) Preconditioner for F, size(P)=[Nj x Nk]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`Q0`](/classes/transforms/wvtransformboussinesq/q0.html) Preconditioner for G, size(Q)=[Nj 1]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`QG0`](/classes/transforms/wvtransformboussinesq/qg0.html) 
  + [`QG0inv`](/classes/transforms/wvtransformboussinesq/qg0inv.html) 
  + [`QGpm`](/classes/transforms/wvtransformboussinesq/qgpm.html) 
  + [`QGpmInv`](/classes/transforms/wvtransformboussinesq/qgpminv.html) 
  + [`QGwg`](/classes/transforms/wvtransformboussinesq/qgwg.html) size(PF,PG)=[Nj x Nj x Nk]
  + [`Qpm`](/classes/transforms/wvtransformboussinesq/qpm.html) Preconditioner for G, size(Q)=[Nj x Nk]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`UA0`](/classes/transforms/wvtransformboussinesq/ua0.html) 
  + [`UAm`](/classes/transforms/wvtransformboussinesq/uam.html) 
  + [`UAp`](/classes/transforms/wvtransformboussinesq/uap.html) 
  + [`VA0`](/classes/transforms/wvtransformboussinesq/va0.html) 
  + [`VAm`](/classes/transforms/wvtransformboussinesq/vam.html) 
  + [`VAp`](/classes/transforms/wvtransformboussinesq/vap.html) 
  + [`WAm`](/classes/transforms/wvtransformboussinesq/wam.html) 
  + [`WAp`](/classes/transforms/wvtransformboussinesq/wap.html) 
  + [`X`](/classes/transforms/wvtransformboussinesq/x_.html) 
  + [`Y`](/classes/transforms/wvtransformboussinesq/y_.html) 
  + [`Z`](/classes/transforms/wvtransformboussinesq/z_.html) 
  + [`beta`](/classes/transforms/wvtransformboussinesq/beta.html) 
  + [`buildVerticalModeProjectionOperators`](/classes/transforms/wvtransformboussinesq/buildverticalmodeprojectionoperators.html) 
  + [`chebfunForZArray`](/classes/transforms/wvtransformboussinesq/chebfunforzarray.html) 
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformboussinesq/classrequiredpropertynames.html) 
  + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformboussinesq/crossspectrumwithfgtransform.html) 
  + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformboussinesq/crossspectrumwithggtransform.html) 
  + [`dLnN2`](/classes/transforms/wvtransformboussinesq/dlnn2.html) 
  + [`delta_uhat`](/classes/transforms/wvtransformboussinesq/delta_uhat.html) 
  + [`delta_vhat`](/classes/transforms/wvtransformboussinesq/delta_vhat.html) 
  + [`diffX`](/classes/transforms/wvtransformboussinesq/diffx.html) 
  + [`diffY`](/classes/transforms/wvtransformboussinesq/diffy.html) 
  + [`diffZF`](/classes/transforms/wvtransformboussinesq/diffzf.html) 
  + [`diffZG`](/classes/transforms/wvtransformboussinesq/diffzg.html) 
  + [`effectiveJMax`](/classes/transforms/wvtransformboussinesq/effectivejmax.html) 
  + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformboussinesq/enstrophyfluxfromf0.html) 
  + [`exactPotentialEnstrophy`](/classes/transforms/wvtransformboussinesq/exactpotentialenstrophy.html) 
  + [`exactTotalEnergy`](/classes/transforms/wvtransformboussinesq/exacttotalenergy.html) 
  + [`f`](/classes/transforms/wvtransformboussinesq/f.html) 
  + [`fluxForForcing`](/classes/transforms/wvtransformboussinesq/fluxforforcing.html) 
  + [`g`](/classes/transforms/wvtransformboussinesq/g.html) 
  + [`geometryFromFile`](/classes/transforms/wvtransformboussinesq/geometryfromfile.html) 
  + [`geometryFromGroup`](/classes/transforms/wvtransformboussinesq/geometryfromgroup.html) 
  + [`h_0`](/classes/transforms/wvtransformboussinesq/h_0.html) [Nj 1]
  + [`h_pm`](/classes/transforms/wvtransformboussinesq/h_pm.html) 
  + [`iK2unique`](/classes/transforms/wvtransformboussinesq/ik2unique.html) map from 2-dim K2, to 1-dim K2unique
  + [`iOmega`](/classes/transforms/wvtransformboussinesq/iomega.html) 
  + [`inertialPeriod`](/classes/transforms/wvtransformboussinesq/inertialperiod.html) 
  + [`j`](/classes/transforms/wvtransformboussinesq/j.html) 
  + [`kAxis`](/classes/transforms/wvtransformboussinesq/kaxis.html) 
  + [`kPseudoRadial`](/classes/transforms/wvtransformboussinesq/kpseudoradial.html) 
  + [`kljGrid`](/classes/transforms/wvtransformboussinesq/kljgrid.html) 
  + [`lAxis`](/classes/transforms/wvtransformboussinesq/laxis.html) 
  + [`latitude`](/classes/transforms/wvtransformboussinesq/latitude.html) 
  + [`maxFg`](/classes/transforms/wvtransformboussinesq/maxfg.html) 
  + [`maxFw`](/classes/transforms/wvtransformboussinesq/maxfw.html) 
  + [`modeNumberFromIndex`](/classes/transforms/wvtransformboussinesq/modenumberfromindex.html) 
  + [`nK2unique`](/classes/transforms/wvtransformboussinesq/nk2unique.html) number of unique squared-wavenumbers
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformboussinesq/namesofrequiredpropertiesforgeometry.html) 
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformboussinesq/namesofrequiredpropertiesforrotatingfplane.html) 
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformboussinesq/namesofrequiredpropertiesfortransform.html) 
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformboussinesq/namesoftransformvariables.html) 
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformboussinesq/newnonrequiredpropertynames.html) 
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformboussinesq/newrequiredpropertynames.html) 
  + [`planetaryRadius`](/classes/transforms/wvtransformboussinesq/planetaryradius.html) 
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformboussinesq/propertyannotationsforrotatingfplane.html) 
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformboussinesq/qgpvfluxfromf0.html) 
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformboussinesq/requiredpropertiesforgeometryfromgroup.html) 
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformboussinesq/requiredpropertiesforrotatingfplanefromgroup.html) 
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformboussinesq/requiredpropertiesfortransformfromgroup.html) 
  + [`rho0`](/classes/transforms/wvtransformboussinesq/rho0.html) , dLnN2
  + [`rhoFunction`](/classes/transforms/wvtransformboussinesq/rhofunction.html) eta_true operation needs rhoFunction
  + [`rho_nm0`](/classes/transforms/wvtransformboussinesq/rho_nm0.html) 
  + [`rotationRate`](/classes/transforms/wvtransformboussinesq/rotationrate.html) 
  + [`spatialFluxForForcingWithName`](/classes/transforms/wvtransformboussinesq/spatialfluxforforcingwithname.html) 
  + [`spatialMatrixSize`](/classes/transforms/wvtransformboussinesq/spatialmatrixsize.html) 
  + [`spectralMatrixSize`](/classes/transforms/wvtransformboussinesq/spectralmatrixsize.html) 
  + [`spectrumWithFgTransform`](/classes/transforms/wvtransformboussinesq/spectrumwithfgtransform.html) 
  + [`spectrumWithGgTransform`](/classes/transforms/wvtransformboussinesq/spectrumwithggtransform.html) 
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformboussinesq/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`totalEnstrophy`](/classes/transforms/wvtransformboussinesq/totalenstrophy.html) 
  + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformboussinesq/totalenstrophyspatiallyintegrated.html) 
  + [`transformFromGroup`](/classes/transforms/wvtransformboussinesq/transformfromgroup.html) 
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
  + [`verticalModes`](/classes/transforms/wvtransformboussinesq/verticalmodes.html) 
  + [`verticalProjectionOperatorsWithFreeSurface`](/classes/transforms/wvtransformboussinesq/verticalprojectionoperatorswithfreesurface.html) 
  + [`volumeIntegral`](/classes/transforms/wvtransformboussinesq/volumeintegral.html) 
  + [`waveCoefficientsAtTimeT`](/classes/transforms/wvtransformboussinesq/wavecoefficientsattimet.html) 
  + [`waveVortexTransformWithExplicitAntialiasing`](/classes/transforms/wvtransformboussinesq/wavevortextransformwithexplicitantialiasing.html) 
  + [`wvBuffer`](/classes/transforms/wvtransformboussinesq/wvbuffer.html) 
  + [`xyzGrid`](/classes/transforms/wvtransformboussinesq/xyzgrid.html) 
  + [`z`](/classes/transforms/wvtransformboussinesq/z.html) 
  + [`z_int`](/classes/transforms/wvtransformboussinesq/z_int.html) 


---