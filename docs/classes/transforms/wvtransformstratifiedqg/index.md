---
layout: default
title: WVTransformStratifiedQG
has_children: false
has_toc: false
mathjax: true
parent: Transforms
grand_parent: Class documentation
nav_order: 6
---

#  WVTransformStratifiedQG

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
  + [`WVTransformStratifiedQG`](/classes/transforms/wvtransformstratifiedqg/wvtransformstratifiedqg.html) create a wave-vortex transform for variable stratification
+ Primary flow components
  + [`geostrophicComponent`](/classes/transforms/wvtransformstratifiedqg/geostrophiccomponent.html) returns the geostrophic flow component
+ Stratification
  + [`N2`](/classes/transforms/wvtransformstratifiedqg/n2.html) $$N^2(z)$$, squared buoyancy frequency of the no-motion density, $$N^2\equiv - \frac{g}{\rho_0} \frac{\partial \rho_\textrm{nm}}{\partial z}$$
  + [`dLnN2`](/classes/transforms/wvtransformstratifiedqg/dlnn2.html) $$\frac{\partial \ln N^2}{\partial z}$$, vertical variation of the log of the squared buoyancy frequency
  + [`verticalModes`](/classes/transforms/wvtransformstratifiedqg/verticalmodes.html) instance of the InternalModes class
  + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformstratifiedqg/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
  + Vertical modes
    + [`FMatrix`](/classes/transforms/wvtransformstratifiedqg/fmatrix.html) transformation matrix $$F_g$$
    + [`FinvMatrix`](/classes/transforms/wvtransformstratifiedqg/finvmatrix.html) transformation matrix $$F_g^{-1}$$
    + [`GMatrix`](/classes/transforms/wvtransformstratifiedqg/gmatrix.html) transformation matrix $$G_g$$
    + [`GinvMatrix`](/classes/transforms/wvtransformstratifiedqg/ginvmatrix.html) transformation matrix $$G_g^{-1}$$
  + Validation
    + [`isDensityInValidRange`](/classes/transforms/wvtransformstratifiedqg/isdensityinvalidrange.html) checks if the density field is a valid adiabatic re-arrangement of the base state
+ Initial conditions
  + Geostrophic Motions
    + [`initWithGeostrophicStreamfunction`](/classes/transforms/wvtransformstratifiedqg/initwithgeostrophicstreamfunction.html) initialize with a geostrophic streamfunction
    + [`setGeostrophicStreamfunction`](/classes/transforms/wvtransformstratifiedqg/setgeostrophicstreamfunction.html) set a geostrophic streamfunction
    + [`addGeostrophicStreamfunction`](/classes/transforms/wvtransformstratifiedqg/addgeostrophicstreamfunction.html) add a geostrophic streamfunction to existing geostrophic motions
    + [`setGeostrophicModes`](/classes/transforms/wvtransformstratifiedqg/setgeostrophicmodes.html) set amplitudes of the given geostrophic modes
    + [`addGeostrophicModes`](/classes/transforms/wvtransformstratifiedqg/addgeostrophicmodes.html) add amplitudes of the given geostrophic modes
    + [`removeAllGeostrophicMotions`](/classes/transforms/wvtransformstratifiedqg/removeallgeostrophicmotions.html) remove all geostrophic motions
+ Energetics of flow components
  + [`geostrophicEnergy`](/classes/transforms/wvtransformstratifiedqg/geostrophicenergy.html) total energy, geostrophic
+ Operations
  + Grid transformation
    + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformstratifiedqg/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
    + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformstratifiedqg/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
  + Fourier transformation
    + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformstratifiedqg/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
    + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
    + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
  + Transformations
    + [`transformToKLAxes`](/classes/transforms/wvtransformstratifiedqg/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
    + [`transformToOmegaAxis`](/classes/transforms/wvtransformstratifiedqg/transformtoomegaaxis.html) transforms in the from (j,kRadial) to omegaAxis
    + [`transformToPseudoRadialWavenumber`](/classes/transforms/wvtransformstratifiedqg/transformtopseudoradialwavenumber.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberA0`](/classes/transforms/wvtransformstratifiedqg/transformtopseudoradialwavenumbera0.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberApm`](/classes/transforms/wvtransformstratifiedqg/transformtopseudoradialwavenumberapm.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToRadialWavenumber`](/classes/transforms/wvtransformstratifiedqg/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
+ Wave-vortex coefficients
  + at time $$t$$
    + [`A0t`](/classes/transforms/wvtransformstratifiedqg/a0t.html) geostrophic coefficients time t
+ Domain Attributes
  + [`f`](/classes/transforms/wvtransformstratifiedqg/f.html) Coriolis parameter
  + [`g`](/classes/transforms/wvtransformstratifiedqg/g.html) gravity of Earth
  + [`inertialPeriod`](/classes/transforms/wvtransformstratifiedqg/inertialperiod.html) inertial period
  + [`latitude`](/classes/transforms/wvtransformstratifiedqg/latitude.html) central latitude of the simulation
  + [`planetaryRadius`](/classes/transforms/wvtransformstratifiedqg/planetaryradius.html) radius of the planetary body
  + [`rho0`](/classes/transforms/wvtransformstratifiedqg/rho0.html) , dLnN2
  + [`rotationRate`](/classes/transforms/wvtransformstratifiedqg/rotationrate.html) rotation rate of the planetary body
  + Grid
    + Spectral
      + [`J`](/classes/transforms/wvtransformstratifiedqg/j_.html) j-coordinate matrix
      + [`K`](/classes/transforms/wvtransformstratifiedqg/k_.html) k-coordinate matrix
      + [`K2`](/classes/transforms/wvtransformstratifiedqg/k2.html) squared horizontal wavenumber, $$K2=K^2+L^2$$
      + [`Kh`](/classes/transforms/wvtransformstratifiedqg/kh.html) horizontal wavenumber, $$Kh=\sqrt(K^2+L^2)$$
      + [`L`](/classes/transforms/wvtransformstratifiedqg/l_.html) l-coordinate matrix
      + [`Nj`](/classes/transforms/wvtransformstratifiedqg/nj.html) points in the j-coordinate, `length(z)`
    + Spatial
      + [`Nz`](/classes/transforms/wvtransformstratifiedqg/nz.html) points in the third, untransformed, dimension
      + [`X`](/classes/transforms/wvtransformstratifiedqg/x_.html) x-coordinate matrix
      + [`Y`](/classes/transforms/wvtransformstratifiedqg/y_.html) y-coordinate matrix
      + [`Z`](/classes/transforms/wvtransformstratifiedqg/z_.html) z-coordinate matrix
  + Spatial grid
    + [`x`](/classes/transforms/wvtransformstratifiedqg/x.html) dimension
    + [`y`](/classes/transforms/wvtransformstratifiedqg/y.html) dimension
    + [`Lx`](/classes/transforms/wvtransformstratifiedqg/lx.html) length of the x-dimension
    + [`Ly`](/classes/transforms/wvtransformstratifiedqg/ly.html) length of the y-dimension
    + [`Lz`](/classes/transforms/wvtransformstratifiedqg/lz.html) length of the z-dimension
    + [`Nx`](/classes/transforms/wvtransformstratifiedqg/nx.html) number of grid points in the x-dimension
    + [`Ny`](/classes/transforms/wvtransformstratifiedqg/ny.html) number of grid points in the y-dimension
    + [`fastTransform`](/classes/transforms/wvtransformstratifiedqg/fasttransform.html) fast transform object
  + DFT grid
    + [`Nk_dft`](/classes/transforms/wvtransformstratifiedqg/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
    + [`Nl_dft`](/classes/transforms/wvtransformstratifiedqg/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
    + [`conjugateDimension`](/classes/transforms/wvtransformstratifiedqg/conjugatedimension.html) assumed conjugate dimension
    + [`kMode_dft`](/classes/transforms/wvtransformstratifiedqg/kmode_dft.html) k mode-number on the DFT grid
    + [`k_dft`](/classes/transforms/wvtransformstratifiedqg/k_dft.html) k wavenumber dimension on the DFT grid
    + [`lMode_dft`](/classes/transforms/wvtransformstratifiedqg/lmode_dft.html) l mode-number on the DFT grid
    + [`l_dft`](/classes/transforms/wvtransformstratifiedqg/l_dft.html) l wavenumber dimension on the DFT grid
  + WV grid
    + [`Nkl`](/classes/transforms/wvtransformstratifiedqg/nkl.html) length of the combined kl-wavenumber dimension on the WV grid
    + [`dftConjugateIndex`](/classes/transforms/wvtransformstratifiedqg/dftconjugateindex.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftConjugateIndices2D`](/classes/transforms/wvtransformstratifiedqg/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftPrimaryIndex`](/classes/transforms/wvtransformstratifiedqg/dftprimaryindex.html) index into the DFT grid of each WV mode
    + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformstratifiedqg/dftprimaryindices2d.html) index into the DFT grid of each WV mode
    + [`dk`](/classes/transforms/wvtransformstratifiedqg/dk.html) wavenumber spacing of the $$k$$ axis
    + [`dl`](/classes/transforms/wvtransformstratifiedqg/dl.html) wavenumber spacing of the $$l$$ axis
    + [`k`](/classes/transforms/wvtransformstratifiedqg/k.html) wavenumber dimension on the WV grid
    + [`kMode_wv`](/classes/transforms/wvtransformstratifiedqg/kmode_wv.html) k mode number on the WV grid
    + [`kRadial`](/classes/transforms/wvtransformstratifiedqg/kradial.html) radial (k,l) wavenumber on the WV grid
    + [`kl`](/classes/transforms/wvtransformstratifiedqg/kl.html) wavenumber dimension
    + [`l`](/classes/transforms/wvtransformstratifiedqg/l.html) wavenumber dimension on the WV grid
    + [`lMode_wv`](/classes/transforms/wvtransformstratifiedqg/lmode_wv.html) l mode number on the WV grid
    + [`shouldAntialias`](/classes/transforms/wvtransformstratifiedqg/shouldantialias.html) whether the WV grid includes quadratically aliased wavenumbers
    + [`shouldExcludeNyquist`](/classes/transforms/wvtransformstratifiedqg/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
    + [`shouldExludeConjugates`](/classes/transforms/wvtransformstratifiedqg/shouldexludeconjugates.html) whether the WV grid includes wavenumbers that are Hermitian conjugates
    + [`wvConjugateIndex`](/classes/transforms/wvtransformstratifiedqg/wvconjugateindex.html) index into the WV mode that matches the dftConjugateIndices
  + Stratification
    + [`h_0`](/classes/transforms/wvtransformstratifiedqg/h_0.html) [Nj 1]
+ Utility function
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformstratifiedqg/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformstratifiedqg/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformstratifiedqg/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isHermitian`](/classes/transforms/wvtransformstratifiedqg/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`setConjugateToUnity`](/classes/transforms/wvtransformstratifiedqg/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
+ Properties
  + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformstratifiedqg/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
+ Energetics
  + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformstratifiedqg/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
  + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformstratifiedqg/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
+ Index gymnastics
  + [`indexFromKLModeNumber`](/classes/transforms/wvtransformstratifiedqg/indexfromklmodenumber.html) return the linear index into k_wv and l_wv from a mode number
  + [`indexFromModeNumber`](/classes/transforms/wvtransformstratifiedqg/indexfrommodenumber.html) return the linear index into a spectral matrix given (k,l,j)
  + [`indicesFromDFTGridToWVGrid`](/classes/transforms/wvtransformstratifiedqg/indicesfromdftgridtowvgrid.html) indices to convert from DFT to WV grid
  + [`indicesFromWVGridToDFTGrid`](/classes/transforms/wvtransformstratifiedqg/indicesfromwvgridtodftgrid.html) indices to convert from WV to DFT grid
  + [`indicesFromWVGridToFFTWGrid`](/classes/transforms/wvtransformstratifiedqg/indicesfromwvgridtofftwgrid.html) indices to convert from WV to DFT grid
  + [`isValidConjugateKLModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidconjugateklmodenumber.html) return a boolean indicating whether (k,l) is a valid conjugate WV mode number
  + [`isValidConjugateModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid conjugate mode number
  + [`isValidKLModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidklmodenumber.html) return a boolean indicating whether (k,l) is a valid WV mode number
  + [`isValidModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
  + [`isValidPrimaryKLModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidprimaryklmodenumber.html) return a boolean indicating whether (k,l) is a valid primary (non-conjugate) WV mode number
  + [`isValidPrimaryModeNumber`](/classes/transforms/wvtransformstratifiedqg/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid primary (non-conjugate) mode number
  + [`klModeNumberFromIndex`](/classes/transforms/wvtransformstratifiedqg/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
  + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformstratifiedqg/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
+ Masks
  + [`maskForAliasedModes`](/classes/transforms/wvtransformstratifiedqg/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
  + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformstratifiedqg/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
  + [`maskForNyquistModes`](/classes/transforms/wvtransformstratifiedqg/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
+ Utilities
  + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformstratifiedqg/placeparticlesonisopycnal.html) places Lagrangian particles along a specified isopycnal
+ Developer
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformstratifiedqg/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
+ State Variables
  + [`psi`](/classes/transforms/wvtransformstratifiedqg/psi.html) geostrophic streamfunction
  + [`ssu`](/classes/transforms/wvtransformstratifiedqg/ssu.html) x-component of the fluid velocity at the surface
  + [`ssv`](/classes/transforms/wvtransformstratifiedqg/ssv.html) y-component of the fluid velocity at the surface
+ Potential Vorticity & Enstrophy
  + [`qgpv`](/classes/transforms/wvtransformstratifiedqg/qgpv.html) quasigeostrophic potential vorticity
+ Internal
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformstratifiedqg/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformstratifiedqg/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors
+ Other
  + [`A0N`](/classes/transforms/wvtransformstratifiedqg/a0n.html) matrix component that multiplies $$\tilde{\eta}$$ to compute $$A_0$$.
  + [`A0U`](/classes/transforms/wvtransformstratifiedqg/a0u.html) matrix component that multiplies $$\tilde{u}$$ to compute $$A_0$$.
  + [`A0V`](/classes/transforms/wvtransformstratifiedqg/a0v.html) matrix component that multiplies $$\tilde{v}$$ to compute $$A_0$$.
  + [`A0Z`](/classes/transforms/wvtransformstratifiedqg/a0z.html) 
  + [`Lr2`](/classes/transforms/wvtransformstratifiedqg/lr2.html) squared Rossby radius
  + [`N2Function`](/classes/transforms/wvtransformstratifiedqg/n2function.html) takes $$z$$ values and returns the squared buoyancy frequency of the no-motion density.
  + [`NA0`](/classes/transforms/wvtransformstratifiedqg/na0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{\eta}$$.
  + [`P0`](/classes/transforms/wvtransformstratifiedqg/p0.html) Preconditioner for F, size(P)=[Nj 1]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`PA0`](/classes/transforms/wvtransformstratifiedqg/pa0.html) 
  + [`PF0`](/classes/transforms/wvtransformstratifiedqg/pf0.html) size(PF,PG)=[Nj x Nz]
  + [`PF0inv`](/classes/transforms/wvtransformstratifiedqg/pf0inv.html) Transformation matrices
  + [`Q0`](/classes/transforms/wvtransformstratifiedqg/q0.html) Preconditioner for G, size(Q)=[Nj 1]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`QG0`](/classes/transforms/wvtransformstratifiedqg/qg0.html) Preconditioned G-mode forward transformation
  + [`QG0inv`](/classes/transforms/wvtransformstratifiedqg/qg0inv.html) Preconditioned G-mode inverse transformation
  + [`UA0`](/classes/transforms/wvtransformstratifiedqg/ua0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{u}$$.
  + [`VA0`](/classes/transforms/wvtransformstratifiedqg/va0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{v}$$.
  + [`beta`](/classes/transforms/wvtransformstratifiedqg/beta.html) 
  + [`buoyancyPeriod`](/classes/transforms/wvtransformstratifiedqg/buoyancyperiod.html) 
  + [`chebfunForZArray`](/classes/transforms/wvtransformstratifiedqg/chebfunforzarray.html) 
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformstratifiedqg/classrequiredpropertynames.html) 
  + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformstratifiedqg/crossspectrumwithfgtransform.html) 
  + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformstratifiedqg/crossspectrumwithggtransform.html) 
  + [`diffX`](/classes/transforms/wvtransformstratifiedqg/diffx.html) 
  + [`diffY`](/classes/transforms/wvtransformstratifiedqg/diffy.html) 
  + [`diffZF`](/classes/transforms/wvtransformstratifiedqg/diffzf.html) 
  + [`diffZG`](/classes/transforms/wvtransformstratifiedqg/diffzg.html) 
  + [`effectiveJMax`](/classes/transforms/wvtransformstratifiedqg/effectivejmax.html) 
  + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformstratifiedqg/enstrophyfluxfromf0.html) 
  + [`eta`](/classes/transforms/wvtransformstratifiedqg/eta.html) approximate isopycnal deviation
  + [`fluxForForcing`](/classes/transforms/wvtransformstratifiedqg/fluxforforcing.html) 
  + [`geometryFromFile`](/classes/transforms/wvtransformstratifiedqg/geometryfromfile.html) 
  + [`geometryFromGroup`](/classes/transforms/wvtransformstratifiedqg/geometryfromgroup.html) 
  + [`h_pm`](/classes/transforms/wvtransformstratifiedqg/h_pm.html) 
  + [`hydrostaticTransform`](/classes/transforms/wvtransformstratifiedqg/hydrostatictransform.html) 
  + [`intZF`](/classes/transforms/wvtransformstratifiedqg/intzf.html)
  + [`intZG`](/classes/transforms/wvtransformstratifiedqg/intzg.html)
  + [`j`](/classes/transforms/wvtransformstratifiedqg/j.html) vertical mode number
  + [`kAxis`](/classes/transforms/wvtransformstratifiedqg/kaxis.html) k coordinate
  + [`kPseudoRadial`](/classes/transforms/wvtransformstratifiedqg/kpseudoradial.html) 
  + [`kljGrid`](/classes/transforms/wvtransformstratifiedqg/kljgrid.html) 
  + [`lAxis`](/classes/transforms/wvtransformstratifiedqg/laxis.html) l coordinate
  + [`maxFg`](/classes/transforms/wvtransformstratifiedqg/maxfg.html) 
  + [`maxFw`](/classes/transforms/wvtransformstratifiedqg/maxfw.html) 
  + [`modeNumberFromIndex`](/classes/transforms/wvtransformstratifiedqg/modenumberfromindex.html) 
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformstratifiedqg/namesofrequiredpropertiesforgeometry.html) 
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformstratifiedqg/namesofrequiredpropertiesforrotatingfplane.html) 
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformstratifiedqg/namesofrequiredpropertiesfortransform.html) 
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformstratifiedqg/namesoftransformvariables.html) 
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformstratifiedqg/newnonrequiredpropertynames.html) 
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformstratifiedqg/newrequiredpropertynames.html) 
  + [`p`](/classes/transforms/wvtransformstratifiedqg/p.html) pressure anomaly
  + [`pi`](/classes/transforms/wvtransformstratifiedqg/pi.html) height anomaly
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformstratifiedqg/propertyannotationsforrotatingfplane.html) 
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformstratifiedqg/qgpvfluxfromf0.html) 
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformstratifiedqg/requiredpropertiesforgeometryfromgroup.html) 
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformstratifiedqg/requiredpropertiesforrotatingfplanefromgroup.html) 
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformstratifiedqg/requiredpropertiesfortransformfromgroup.html) 
  + [`rhoFunction`](/classes/transforms/wvtransformstratifiedqg/rhofunction.html) eta_true operation needs rhoFunction
  + [`rho_e`](/classes/transforms/wvtransformstratifiedqg/rho_e.html) excess density
  + [`rho_nm0`](/classes/transforms/wvtransformstratifiedqg/rho_nm0.html) $$\rho_\textrm{nm}(z)$$, no-motion density at time `t0`
  + [`rho_total`](/classes/transforms/wvtransformstratifiedqg/rho_total.html) total potential density
  + [`spatialMatrixSize`](/classes/transforms/wvtransformstratifiedqg/spatialmatrixsize.html) 
  + [`spectralMatrixSize`](/classes/transforms/wvtransformstratifiedqg/spectralmatrixsize.html) 
  + [`spectrumWithFgTransform`](/classes/transforms/wvtransformstratifiedqg/spectrumwithfgtransform.html) 
  + [`spectrumWithGgTransform`](/classes/transforms/wvtransformstratifiedqg/spectrumwithggtransform.html) 
  + [`ssh`](/classes/transforms/wvtransformstratifiedqg/ssh.html) sea-surface height
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformstratifiedqg/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`totalEnstrophy`](/classes/transforms/wvtransformstratifiedqg/totalenstrophy.html) 
  + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformstratifiedqg/totalenstrophyspatiallyintegrated.html) 
  + [`transformFromGroup`](/classes/transforms/wvtransformstratifiedqg/transformfromgroup.html) 
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformstratifiedqg/transformfromspatialdomainwithfio.html) 
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformstratifiedqg/transformfromspatialdomainwithfourier.html) 
  + [`transformQGPVToWaveVortex`](/classes/transforms/wvtransformstratifiedqg/transformqgpvtowavevortex.html) 
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainwithfourier.html) 
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainwithfourieratposition.html) 
  + [`transformWithG_wg`](/classes/transforms/wvtransformstratifiedqg/transformwithg_wg.html) 
  + [`u`](/classes/transforms/wvtransformstratifiedqg/u.html) x-component of the fluid velocity
  + [`uvMax`](/classes/transforms/wvtransformstratifiedqg/uvmax.html) max horizontal fluid speed
  + [`v`](/classes/transforms/wvtransformstratifiedqg/v.html) y-component of the fluid velocity
  + [`verticalProjectionOperatorsWithFreeSurface`](/classes/transforms/wvtransformstratifiedqg/verticalprojectionoperatorswithfreesurface.html) 
  + [`xyzGrid`](/classes/transforms/wvtransformstratifiedqg/xyzgrid.html) 
  + [`z`](/classes/transforms/wvtransformstratifiedqg/z.html) z coordinate
  + [`z_int`](/classes/transforms/wvtransformstratifiedqg/z_int.html) Quadrature weights for the vertical grid
  + [`zeta_z`](/classes/transforms/wvtransformstratifiedqg/zeta_z.html) vertical component of relative vorticity


---
