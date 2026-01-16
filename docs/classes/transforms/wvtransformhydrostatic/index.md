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
  + [`WVTransformHydrostatic`](/classes/transforms/wvtransformhydrostatic/wvtransformhydrostatic.html) create a wave-vortex transform for variable stratification
+ Primary flow components
  + [`geostrophicComponent`](/classes/transforms/wvtransformhydrostatic/geostrophiccomponent.html) returns the geostrophic flow component
  + [`waveComponent`](/classes/transforms/wvtransformhydrostatic/wavecomponent.html) returns the internal gravity wave flow component
  + [`inertialComponent`](/classes/transforms/wvtransformhydrostatic/inertialcomponent.html) returns the inertial oscillation flow component
  + [`mdaComponent`](/classes/transforms/wvtransformhydrostatic/mdacomponent.html) returns the mean density anomaly component
+ Stratification
  + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformhydrostatic/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
  + Validation
    + [`isDensityInValidRange`](/classes/transforms/wvtransformhydrostatic/isdensityinvalidrange.html) checks if the density field is a valid adiabatic re-arrangement of the base state
+ Initial conditions
  + Waves
    + [`addGMSpectrum`](/classes/transforms/wvtransformhydrostatic/addgmspectrum.html) add waves following a Garrett-Munk spectrum
    + [`addWaveModes`](/classes/transforms/wvtransformhydrostatic/addwavemodes.html) add amplitudes of the given wave modes
    + [`addWavesWithFrequencySpectrum`](/classes/transforms/wvtransformhydrostatic/addwaveswithfrequencyspectrum.html) add waves with a specified frequency spectrum
    + [`initWavesWithFrequencySpectrum`](/classes/transforms/wvtransformhydrostatic/initwaveswithfrequencyspectrum.html) initialize with waves of a specified frequency spectrum
    + [`initWithAlternativeSpectrum`](/classes/transforms/wvtransformhydrostatic/initwithalternativespectrum.html) initialize with an alternative formulation of the GM spectrum in the wavenumber domain.
    + [`initWithGMSpectrum`](/classes/transforms/wvtransformhydrostatic/initwithgmspectrum.html) initialize the wave field following a Garrett-Munk spectrum
    + [`initWithWaveModes`](/classes/transforms/wvtransformhydrostatic/initwithwavemodes.html) initialize with the given wave modes
    + [`removeAllWaves`](/classes/transforms/wvtransformhydrostatic/removeallwaves.html) removes all wave from the model, including inertial oscillations
    + [`setWaveModes`](/classes/transforms/wvtransformhydrostatic/setwavemodes.html) set amplitudes of the given wave modes
  + Geostrophic Motions
    + [`initWithGeostrophicStreamfunction`](/classes/transforms/wvtransformhydrostatic/initwithgeostrophicstreamfunction.html) initialize with a geostrophic streamfunction
    + [`setGeostrophicStreamfunction`](/classes/transforms/wvtransformhydrostatic/setgeostrophicstreamfunction.html) set a geostrophic streamfunction
    + [`addGeostrophicStreamfunction`](/classes/transforms/wvtransformhydrostatic/addgeostrophicstreamfunction.html) add a geostrophic streamfunction to existing geostrophic motions
    + [`setGeostrophicModes`](/classes/transforms/wvtransformhydrostatic/setgeostrophicmodes.html) set amplitudes of the given geostrophic modes
    + [`addGeostrophicModes`](/classes/transforms/wvtransformhydrostatic/addgeostrophicmodes.html) add amplitudes of the given geostrophic modes
    + [`removeAllGeostrophicMotions`](/classes/transforms/wvtransformhydrostatic/removeallgeostrophicmotions.html) remove all geostrophic motions
  + Inertial Oscillations
    + [`addInertialMotions`](/classes/transforms/wvtransformhydrostatic/addinertialmotions.html) add inertial motions to existing inertial motions
    + [`initWithInertialMotions`](/classes/transforms/wvtransformhydrostatic/initwithinertialmotions.html) initialize with inertial motions
    + [`removeAllInertialMotions`](/classes/transforms/wvtransformhydrostatic/removeallinertialmotions.html) remove all inertial motions
    + [`setInertialMotions`](/classes/transforms/wvtransformhydrostatic/setinertialmotions.html) set inertial motions
  + Mean density anomaly
    + [`addMeanDensityAnomaly`](/classes/transforms/wvtransformhydrostatic/addmeandensityanomaly.html) add inertial motions to existing inertial motions
    + [`initWithMeanDensityAnomaly`](/classes/transforms/wvtransformhydrostatic/initwithmeandensityanomaly.html) initialize with inertial motions
    + [`removeAllMeanDensityAnomaly`](/classes/transforms/wvtransformhydrostatic/removeallmeandensityanomaly.html) remove all mean density anomalies
    + [`setMeanDensityAnomaly`](/classes/transforms/wvtransformhydrostatic/setmeandensityanomaly.html) set inertial motions
+ Operations
  + Grid transformation
    + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformhydrostatic/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
    + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformhydrostatic/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
  + Fourier transformation
    + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformhydrostatic/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
    + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
    + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
  + Transformations
    + [`transformToKLAxes`](/classes/transforms/wvtransformhydrostatic/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
    + [`transformToOmegaAxis`](/classes/transforms/wvtransformhydrostatic/transformtoomegaaxis.html) transforms in the from (j,kRadial) to omegaAxis
    + [`transformToPseudoRadialWavenumber`](/classes/transforms/wvtransformhydrostatic/transformtopseudoradialwavenumber.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberA0`](/classes/transforms/wvtransformhydrostatic/transformtopseudoradialwavenumbera0.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberApm`](/classes/transforms/wvtransformhydrostatic/transformtopseudoradialwavenumberapm.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToRadialWavenumber`](/classes/transforms/wvtransformhydrostatic/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
+ Domain attributes
  + Spatial grid
    + [`Lx`](/classes/transforms/wvtransformhydrostatic/lx.html) length of the x-dimension
    + [`Ly`](/classes/transforms/wvtransformhydrostatic/ly.html) length of the y-dimension
    + [`Lz`](/classes/transforms/wvtransformhydrostatic/lz.html) length of the z-dimension
    + [`Nx`](/classes/transforms/wvtransformhydrostatic/nx.html) number of grid points in the x-dimension
    + [`Ny`](/classes/transforms/wvtransformhydrostatic/ny.html) number of grid points in the y-dimension
    + [`fastTransform`](/classes/transforms/wvtransformhydrostatic/fasttransform.html) fast transform object
    + [`x`](/classes/transforms/wvtransformhydrostatic/x.html) dimension
    + [`y`](/classes/transforms/wvtransformhydrostatic/y.html) dimension
  + DFT grid
    + [`Nk_dft`](/classes/transforms/wvtransformhydrostatic/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
    + [`Nl_dft`](/classes/transforms/wvtransformhydrostatic/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
    + [`conjugateDimension`](/classes/transforms/wvtransformhydrostatic/conjugatedimension.html) assumed conjugate dimension
    + [`kMode_dft`](/classes/transforms/wvtransformhydrostatic/kmode_dft.html) k mode-number on the DFT grid
    + [`k_dft`](/classes/transforms/wvtransformhydrostatic/k_dft.html) k wavenumber dimension on the DFT grid
    + [`lMode_dft`](/classes/transforms/wvtransformhydrostatic/lmode_dft.html) l mode-number on the DFT grid
    + [`l_dft`](/classes/transforms/wvtransformhydrostatic/l_dft.html) l wavenumber dimension on the DFT grid
  + WV grid
    + [`Nkl`](/classes/transforms/wvtransformhydrostatic/nkl.html) length of the combined kl-wavenumber dimension on the WV grid
    + [`dftConjugateIndex`](/classes/transforms/wvtransformhydrostatic/dftconjugateindex.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftConjugateIndices2D`](/classes/transforms/wvtransformhydrostatic/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftPrimaryIndex`](/classes/transforms/wvtransformhydrostatic/dftprimaryindex.html) index into the DFT grid of each WV mode
    + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformhydrostatic/dftprimaryindices2d.html) index into the DFT grid of each WV mode
    + [`dk`](/classes/transforms/wvtransformhydrostatic/dk.html) wavenumber spacing of the $$k$$ axis
    + [`dl`](/classes/transforms/wvtransformhydrostatic/dl.html) wavenumber spacing of the $$l$$ axis
    + [`k`](/classes/transforms/wvtransformhydrostatic/k.html) wavenumber dimension on the WV grid
    + [`kMode_wv`](/classes/transforms/wvtransformhydrostatic/kmode_wv.html) k mode number on the WV grid
    + [`kRadial`](/classes/transforms/wvtransformhydrostatic/kradial.html) radial (k,l) wavenumber on the WV grid
    + [`kl`](/classes/transforms/wvtransformhydrostatic/kl.html) wavenumber dimension
    + [`l`](/classes/transforms/wvtransformhydrostatic/l.html) wavenumber dimension on the WV grid
    + [`lMode_wv`](/classes/transforms/wvtransformhydrostatic/lmode_wv.html) l mode number on the WV grid
    + [`shouldAntialias`](/classes/transforms/wvtransformhydrostatic/shouldantialias.html) whether the WV grid includes quadratically aliased wavenumbers
    + [`shouldExcludeNyquist`](/classes/transforms/wvtransformhydrostatic/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
    + [`shouldExludeConjugates`](/classes/transforms/wvtransformhydrostatic/shouldexludeconjugates.html) whether the WV grid includes wavenumbers that are Hermitian conjugates
    + [`wvConjugateIndex`](/classes/transforms/wvtransformhydrostatic/wvconjugateindex.html) index into the WV mode that matches the dftConjugateIndices
+ Utility function
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformhydrostatic/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformhydrostatic/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformhydrostatic/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isHermitian`](/classes/transforms/wvtransformhydrostatic/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`setConjugateToUnity`](/classes/transforms/wvtransformhydrostatic/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
+ Properties
  + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformhydrostatic/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
+ Energetics
  + [`geostrophicEnergy`](/classes/transforms/wvtransformhydrostatic/geostrophicenergy.html) total energy of the geostrophic flow
  + [`inertialEnergy`](/classes/transforms/wvtransformhydrostatic/inertialenergy.html) total energy of the inertial flow
  + [`mdaEnergy`](/classes/transforms/wvtransformhydrostatic/mdaenergy.html) total energy of the mean density anomaly
  + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformhydrostatic/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
  + [`waveEnergy`](/classes/transforms/wvtransformhydrostatic/waveenergy.html) total energy of the geostrophic flow
  + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformhydrostatic/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
+ Index gymnastics
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
  + [`klModeNumberFromIndex`](/classes/transforms/wvtransformhydrostatic/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
  + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformhydrostatic/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
+ Masks
  + [`maskForAliasedModes`](/classes/transforms/wvtransformhydrostatic/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
  + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformhydrostatic/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
  + [`maskForNyquistModes`](/classes/transforms/wvtransformhydrostatic/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
+ Utilities
  + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformhydrostatic/placeparticlesonisopycnal.html) places Lagrangian particles along a specified isopycnal
+ Developer
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformhydrostatic/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
+ Internal
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformhydrostatic/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformhydrostatic/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors
+ Other
  + [`A0N`](/classes/transforms/wvtransformhydrostatic/a0n.html) 
  + [`A0Z`](/classes/transforms/wvtransformhydrostatic/a0z.html) 
  + [`ApmD`](/classes/transforms/wvtransformhydrostatic/apmd.html) 
  + [`ApmN`](/classes/transforms/wvtransformhydrostatic/apmn.html) 
  + [`FMatrix`](/classes/transforms/wvtransformhydrostatic/fmatrix.html) 
  + [`Feta`](/classes/transforms/wvtransformhydrostatic/feta.html) 
  + [`FinvMatrix`](/classes/transforms/wvtransformhydrostatic/finvmatrix.html) 
  + [`Fu`](/classes/transforms/wvtransformhydrostatic/fu.html) 
  + [`Fv`](/classes/transforms/wvtransformhydrostatic/fv.html) 
  + [`GMatrix`](/classes/transforms/wvtransformhydrostatic/gmatrix.html) 
  + [`GinvMatrix`](/classes/transforms/wvtransformhydrostatic/ginvmatrix.html) 
  + [`J`](/classes/transforms/wvtransformhydrostatic/j_.html) 
  + [`K`](/classes/transforms/wvtransformhydrostatic/k_.html) 
  + [`K2`](/classes/transforms/wvtransformhydrostatic/k2.html) 
  + [`Kh`](/classes/transforms/wvtransformhydrostatic/kh.html) 
  + [`L`](/classes/transforms/wvtransformhydrostatic/l_.html) 
  + [`Lr2`](/classes/transforms/wvtransformhydrostatic/lr2.html) 
  + [`N2`](/classes/transforms/wvtransformhydrostatic/n2.html) 
  + [`N2Function`](/classes/transforms/wvtransformhydrostatic/n2function.html) 
  + [`NA0`](/classes/transforms/wvtransformhydrostatic/na0.html) 
  + [`NAm`](/classes/transforms/wvtransformhydrostatic/nam.html) 
  + [`NAp`](/classes/transforms/wvtransformhydrostatic/nap.html) 
  + [`Nj`](/classes/transforms/wvtransformhydrostatic/nj.html) 
  + [`Nz`](/classes/transforms/wvtransformhydrostatic/nz.html) 
  + [`Omega`](/classes/transforms/wvtransformhydrostatic/omega.html) 
  + [`P0`](/classes/transforms/wvtransformhydrostatic/p0.html) Preconditioner for F, size(P)=[Nj 1]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`PA0`](/classes/transforms/wvtransformhydrostatic/pa0.html) 
  + [`PF0`](/classes/transforms/wvtransformhydrostatic/pf0.html) size(PF,PG)=[Nj x Nz]
  + [`PF0inv`](/classes/transforms/wvtransformhydrostatic/pf0inv.html) Transformation matrices
  + [`Q0`](/classes/transforms/wvtransformhydrostatic/q0.html) Preconditioner for G, size(Q)=[Nj 1]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`QG0`](/classes/transforms/wvtransformhydrostatic/qg0.html) 
  + [`QG0inv`](/classes/transforms/wvtransformhydrostatic/qg0inv.html) 
  + [`UA0`](/classes/transforms/wvtransformhydrostatic/ua0.html) 
  + [`UAm`](/classes/transforms/wvtransformhydrostatic/uam.html) 
  + [`UAp`](/classes/transforms/wvtransformhydrostatic/uap.html) 
  + [`VA0`](/classes/transforms/wvtransformhydrostatic/va0.html) 
  + [`VAm`](/classes/transforms/wvtransformhydrostatic/vam.html) 
  + [`VAp`](/classes/transforms/wvtransformhydrostatic/vap.html) 
  + [`WAm`](/classes/transforms/wvtransformhydrostatic/wam.html) 
  + [`WAp`](/classes/transforms/wvtransformhydrostatic/wap.html) 
  + [`X`](/classes/transforms/wvtransformhydrostatic/x_.html) 
  + [`Y`](/classes/transforms/wvtransformhydrostatic/y_.html) 
  + [`Z`](/classes/transforms/wvtransformhydrostatic/z_.html) 
  + [`beta`](/classes/transforms/wvtransformhydrostatic/beta.html) 
  + [`boussinesqTransform`](/classes/transforms/wvtransformhydrostatic/boussinesqtransform.html) 
  + [`buoyancyPeriod`](/classes/transforms/wvtransformhydrostatic/buoyancyperiod.html) 
  + [`chebfunForZArray`](/classes/transforms/wvtransformhydrostatic/chebfunforzarray.html) 
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformhydrostatic/classrequiredpropertynames.html) 
  + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformhydrostatic/crossspectrumwithfgtransform.html) 
  + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformhydrostatic/crossspectrumwithggtransform.html) 
  + [`dLnN2`](/classes/transforms/wvtransformhydrostatic/dlnn2.html) 
  + [`diffX`](/classes/transforms/wvtransformhydrostatic/diffx.html) 
  + [`diffY`](/classes/transforms/wvtransformhydrostatic/diffy.html) 
  + [`diffZF`](/classes/transforms/wvtransformhydrostatic/diffzf.html) 
  + [`diffZG`](/classes/transforms/wvtransformhydrostatic/diffzg.html) 
  + [`effectiveJMax`](/classes/transforms/wvtransformhydrostatic/effectivejmax.html) 
  + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformhydrostatic/enstrophyfluxfromf0.html) 
  + [`exactPotentialEnstrophy`](/classes/transforms/wvtransformhydrostatic/exactpotentialenstrophy.html) 
  + [`exactTotalEnergy`](/classes/transforms/wvtransformhydrostatic/exacttotalenergy.html) 
  + [`f`](/classes/transforms/wvtransformhydrostatic/f.html) 
  + [`fluxAtTimeCellArray`](/classes/transforms/wvtransformhydrostatic/fluxattimecellarray.html) y0 is a 3x1 cell array
  + [`fluxForForcing`](/classes/transforms/wvtransformhydrostatic/fluxforforcing.html) 
  + [`g`](/classes/transforms/wvtransformhydrostatic/g.html) 
  + [`geometryFromFile`](/classes/transforms/wvtransformhydrostatic/geometryfromfile.html) 
  + [`geometryFromGroup`](/classes/transforms/wvtransformhydrostatic/geometryfromgroup.html) 
  + [`h_0`](/classes/transforms/wvtransformhydrostatic/h_0.html) [Nj 1]
  + [`h_pm`](/classes/transforms/wvtransformhydrostatic/h_pm.html) 
  + [`iOmega`](/classes/transforms/wvtransformhydrostatic/iomega.html) 
  + [`inertialPeriod`](/classes/transforms/wvtransformhydrostatic/inertialperiod.html) 
  + [`j`](/classes/transforms/wvtransformhydrostatic/j.html) 
  + [`kAxis`](/classes/transforms/wvtransformhydrostatic/kaxis.html) 
  + [`kPseudoRadial`](/classes/transforms/wvtransformhydrostatic/kpseudoradial.html) 
  + [`kljGrid`](/classes/transforms/wvtransformhydrostatic/kljgrid.html) 
  + [`lAxis`](/classes/transforms/wvtransformhydrostatic/laxis.html) 
  + [`latitude`](/classes/transforms/wvtransformhydrostatic/latitude.html) 
  + [`maxFg`](/classes/transforms/wvtransformhydrostatic/maxfg.html) 
  + [`maxFw`](/classes/transforms/wvtransformhydrostatic/maxfw.html) 
  + [`modeNumberFromIndex`](/classes/transforms/wvtransformhydrostatic/modenumberfromindex.html) 
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformhydrostatic/namesofrequiredpropertiesforgeometry.html) 
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformhydrostatic/namesofrequiredpropertiesforrotatingfplane.html) 
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformhydrostatic/namesofrequiredpropertiesfortransform.html) 
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformhydrostatic/namesoftransformvariables.html) 
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformhydrostatic/newnonrequiredpropertynames.html) 
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformhydrostatic/newrequiredpropertynames.html) 
  + [`planetaryRadius`](/classes/transforms/wvtransformhydrostatic/planetaryradius.html) 
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformhydrostatic/propertyannotationsforrotatingfplane.html) 
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformhydrostatic/qgpvfluxfromf0.html) 
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformhydrostatic/requiredpropertiesforgeometryfromgroup.html) 
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformhydrostatic/requiredpropertiesforrotatingfplanefromgroup.html) 
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformhydrostatic/requiredpropertiesfortransformfromgroup.html) 
  + [`rho0`](/classes/transforms/wvtransformhydrostatic/rho0.html) , dLnN2
  + [`rhoFunction`](/classes/transforms/wvtransformhydrostatic/rhofunction.html) eta_true operation needs rhoFunction
  + [`rho_nm0`](/classes/transforms/wvtransformhydrostatic/rho_nm0.html) 
  + [`rk4FluxForForcing`](/classes/transforms/wvtransformhydrostatic/rk4fluxforforcing.html) 
  + [`rotationRate`](/classes/transforms/wvtransformhydrostatic/rotationrate.html) 
  + [`spatialFluxForForcingWithName`](/classes/transforms/wvtransformhydrostatic/spatialfluxforforcingwithname.html) 
  + [`spatialMatrixSize`](/classes/transforms/wvtransformhydrostatic/spatialmatrixsize.html) 
  + [`spectralMatrixSize`](/classes/transforms/wvtransformhydrostatic/spectralmatrixsize.html) 
  + [`spectrumWithFgTransform`](/classes/transforms/wvtransformhydrostatic/spectrumwithfgtransform.html) 
  + [`spectrumWithGgTransform`](/classes/transforms/wvtransformhydrostatic/spectrumwithggtransform.html) 
  + [`sumFluxDictionary`](/classes/transforms/wvtransformhydrostatic/sumfluxdictionary.html) 
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformhydrostatic/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`totalEnstrophy`](/classes/transforms/wvtransformhydrostatic/totalenstrophy.html) 
  + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformhydrostatic/totalenstrophyspatiallyintegrated.html) 
  + [`transformFromGroup`](/classes/transforms/wvtransformhydrostatic/transformfromgroup.html) 
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformhydrostatic/transformfromspatialdomainwithfio.html) 
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformhydrostatic/transformfromspatialdomainwithfourier.html) 
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainwithfourier.html) 
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformhydrostatic/transformtospatialdomainwithfourieratposition.html) 
  + [`transformWithG_wg`](/classes/transforms/wvtransformhydrostatic/transformwithg_wg.html) 
  + [`verticalModes`](/classes/transforms/wvtransformhydrostatic/verticalmodes.html) 
  + [`verticalProjectionOperatorsWithFreeSurface`](/classes/transforms/wvtransformhydrostatic/verticalprojectionoperatorswithfreesurface.html) 
  + [`volumeIntegral`](/classes/transforms/wvtransformhydrostatic/volumeintegral.html) 
  + [`waveCoefficientsAtTimeT`](/classes/transforms/wvtransformhydrostatic/wavecoefficientsattimet.html) 
  + [`waveVortexTransformWithExplicitAntialiasing`](/classes/transforms/wvtransformhydrostatic/wavevortextransformwithexplicitantialiasing.html) 
  + [`xyzGrid`](/classes/transforms/wvtransformhydrostatic/xyzgrid.html) 
  + [`z`](/classes/transforms/wvtransformhydrostatic/z.html) 
  + [`z_int`](/classes/transforms/wvtransformhydrostatic/z_int.html) 


---