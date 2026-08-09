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

Represent stratified quasigeostrophic flow with variable stratification.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransformStratifiedQG < <a href="/classes/transforms/wvtransform/" title="WVTransform">WVTransform</a></code></pre></div></div>

## Overview

To initialize an instance of the WVTransformStratifiedQG class you
must specify the domain size, the number of grid points, and either
the density profile or the stratification profile.

```matlab
N0 = 3*2*pi/3600;
L_gm = 1300;
N2 = @(z) N0*N0*exp(2*z/L_gm);
wvt = WVTransformStratifiedQG([100e3,100e3,4000],[64,64,65],N2Function=N2,latitude=30);
```

The quasigeostrophic state is stored in
[`A0`](/classes/transforms/wvtransform/a0.html), with current-time view
`A0t`. This transform has no active `Ap`, `Am`, `Apt`, or `Amt` content.




## Topics
+ Create and restore a transform
  + [`WVTransformStratifiedQG`](/classes/transforms/wvtransformstratifiedqg/wvtransformstratifiedqg.html) Create a stratified quasigeostrophic transform.
+ Inspect wave-vortex coefficients
  + Coefficients at the current time
    + [`A0t`](/classes/transforms/wvtransformstratifiedqg/a0t.html) zero-frequency coefficients at current time t
+ Inspect the domain
  + Spatial grid
    + [`z`](/classes/transforms/wvtransformstratifiedqg/z.html) z coordinate
    + [`Lx`](/classes/transforms/wvtransformstratifiedqg/lx.html) length of the x-dimension
    + [`Ly`](/classes/transforms/wvtransformstratifiedqg/ly.html) length of the y-dimension
    + [`Lz`](/classes/transforms/wvtransformstratifiedqg/lz.html) length of the z-dimension
    + [`Nx`](/classes/transforms/wvtransformstratifiedqg/nx.html) number of grid points in the x-dimension
    + [`Ny`](/classes/transforms/wvtransformstratifiedqg/ny.html) number of grid points in the y-dimension
    + [`Nz`](/classes/transforms/wvtransformstratifiedqg/nz.html) points in the third, untransformed, dimension
    + [`spatialMatrixSize`](/classes/transforms/wvtransformstratifiedqg/spatialmatrixsize.html)
    + [`x`](/classes/transforms/wvtransformstratifiedqg/x.html) dimension
    + [`xyzGrid`](/classes/transforms/wvtransformstratifiedqg/xyzgrid.html)
    + [`y`](/classes/transforms/wvtransformstratifiedqg/y.html) dimension
    + [`z_int`](/classes/transforms/wvtransformstratifiedqg/z_int.html) Quadrature weights for the vertical grid
  + Spectral grid
    + [`Nj`](/classes/transforms/wvtransformstratifiedqg/nj.html) points in the j-coordinate, `length(z)`
    + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformstratifiedqg/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
    + [`effectiveJMax`](/classes/transforms/wvtransformstratifiedqg/effectivejmax.html)
    + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformstratifiedqg/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
    + [`j`](/classes/transforms/wvtransformstratifiedqg/j.html) vertical mode number
    + [`k`](/classes/transforms/wvtransformstratifiedqg/k.html) wavenumber dimension on the WV grid
    + [`kAxis`](/classes/transforms/wvtransformstratifiedqg/kaxis.html) k coordinate
    + [`kljGrid`](/classes/transforms/wvtransformstratifiedqg/kljgrid.html)
    + [`l`](/classes/transforms/wvtransformstratifiedqg/l.html) wavenumber dimension on the WV grid
    + [`lAxis`](/classes/transforms/wvtransformstratifiedqg/laxis.html) l coordinate
    + [`spectralMatrixSize`](/classes/transforms/wvtransformstratifiedqg/spectralmatrixsize.html)
  + Rotation and stratification
    + [`N2`](/classes/transforms/wvtransformstratifiedqg/n2.html) $$N^2(z)$$, squared buoyancy frequency of the no-motion density, $$N^2\equiv - \frac{g}{\rho_0} \frac{\partial \rho_\textrm{nm}}{\partial z}$$
    + [`N2Function`](/classes/transforms/wvtransformstratifiedqg/n2function.html) takes $$z$$ values and returns the squared buoyancy frequency of the no-motion density.
    + [`beta`](/classes/transforms/wvtransformstratifiedqg/beta.html)
    + [`buoyancyPeriod`](/classes/transforms/wvtransformstratifiedqg/buoyancyperiod.html)
    + [`inertialPeriod`](/classes/transforms/wvtransformstratifiedqg/inertialperiod.html) inertial period
    + [`latitude`](/classes/transforms/wvtransformstratifiedqg/latitude.html) central latitude of the simulation
    + [`rhoFunction`](/classes/transforms/wvtransformstratifiedqg/rhofunction.html) eta_true operation needs rhoFunction
    + [`verticalModes`](/classes/transforms/wvtransformstratifiedqg/verticalmodes.html) instance of the InternalModes class
+ Initialize the flow
  + Geostrophic motions
    + [`initWithGeostrophicStreamfunction`](/classes/transforms/wvtransformstratifiedqg/initwithgeostrophicstreamfunction.html) initialize with a geostrophic streamfunction
    + [`setGeostrophicStreamfunction`](/classes/transforms/wvtransformstratifiedqg/setgeostrophicstreamfunction.html) set a geostrophic streamfunction
    + [`addGeostrophicStreamfunction`](/classes/transforms/wvtransformstratifiedqg/addgeostrophicstreamfunction.html) add a geostrophic streamfunction to existing geostrophic motions
    + [`setGeostrophicModes`](/classes/transforms/wvtransformstratifiedqg/setgeostrophicmodes.html) set amplitudes of the given geostrophic modes
    + [`addGeostrophicModes`](/classes/transforms/wvtransformstratifiedqg/addgeostrophicmodes.html) add amplitudes of the given geostrophic modes
    + [`removeAllGeostrophicMotions`](/classes/transforms/wvtransformstratifiedqg/removeallgeostrophicmotions.html) remove all geostrophic motions
+ Evaluate physical fields
  + On the model grid
    + [`eta`](/classes/transforms/wvtransformstratifiedqg/eta.html) approximate isopycnal deviation
    + [`p`](/classes/transforms/wvtransformstratifiedqg/p.html) pressure anomaly
    + [`pi`](/classes/transforms/wvtransformstratifiedqg/pi.html) height anomaly
    + [`qgpv`](/classes/transforms/wvtransformstratifiedqg/qgpv.html) quasigeostrophic potential vorticity
    + [`rho_e`](/classes/transforms/wvtransformstratifiedqg/rho_e.html) excess density
    + [`rho_nm0`](/classes/transforms/wvtransformstratifiedqg/rho_nm0.html) $$\rho_\textrm{nm}(z)$$, no-motion density at time `t0`
    + [`rho_total`](/classes/transforms/wvtransformstratifiedqg/rho_total.html) total potential density
    + [`ssh`](/classes/transforms/wvtransformstratifiedqg/ssh.html) sea-surface height
    + [`ssu`](/classes/transforms/wvtransformstratifiedqg/ssu.html) x-component of the fluid velocity at the surface
    + [`ssv`](/classes/transforms/wvtransformstratifiedqg/ssv.html) y-component of the fluid velocity at the surface
    + [`u`](/classes/transforms/wvtransformstratifiedqg/u.html) x-component of the fluid velocity
    + [`uvMax`](/classes/transforms/wvtransformstratifiedqg/uvmax.html) max horizontal fluid speed
    + [`v`](/classes/transforms/wvtransformstratifiedqg/v.html) y-component of the fluid velocity
    + [`zeta_z`](/classes/transforms/wvtransformstratifiedqg/zeta_z.html) vertical component of relative vorticity
+ Convert representations
  + Physical fields and coefficients
    + [`transformQGPVToWaveVortex`](/classes/transforms/wvtransformstratifiedqg/transformqgpvtowavevortex.html)
+ Differentiate and integrate fields
  + [`diffX`](/classes/transforms/wvtransformstratifiedqg/diffx.html)
  + [`diffY`](/classes/transforms/wvtransformstratifiedqg/diffy.html)
  + [`diffZF`](/classes/transforms/wvtransformstratifiedqg/diffzf.html) Differentiate an F-grid field with respect to z.
  + [`diffZG`](/classes/transforms/wvtransformstratifiedqg/diffzg.html) Differentiate a G-grid field with respect to z.
  + [`intZF`](/classes/transforms/wvtransformstratifiedqg/intzf.html) Return the first antiderivative of an F-representation.
  + [`intZG`](/classes/transforms/wvtransformstratifiedqg/intzg.html) Return the bottom-zero first antiderivative of a G-representation.
+ Analyze the flow
  + Energy and summaries
    + [`geostrophicEnergy`](/classes/transforms/wvtransformstratifiedqg/geostrophicenergy.html) total energy, geostrophic
  + Potential vorticity and enstrophy
    + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformstratifiedqg/enstrophyfluxfromf0.html)
    + [`totalEnstrophy`](/classes/transforms/wvtransformstratifiedqg/totalenstrophy.html)
    + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformstratifiedqg/totalenstrophyspatiallyintegrated.html)
  + Spectra
    + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformstratifiedqg/crossspectrumwithfgtransform.html)
    + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformstratifiedqg/crossspectrumwithggtransform.html)
    + [`transformToPseudoRadialWavenumber`](/classes/transforms/wvtransformstratifiedqg/transformtopseudoradialwavenumber.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberA0`](/classes/transforms/wvtransformstratifiedqg/transformtopseudoradialwavenumbera0.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToPseudoRadialWavenumberApm`](/classes/transforms/wvtransformstratifiedqg/transformtopseudoradialwavenumberapm.html) transforms in the from (j,kRadial) to kPseudoRadial
    + [`transformToRadialWavenumber`](/classes/transforms/wvtransformstratifiedqg/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Inspect wave-vortex coefficients
+ Inspect the domain
+ Initialize the flow
+ Evaluate physical fields
+ Convert representations
+ Analyze the flow
+ Projection and reconstruction coefficients
  + [`A0N`](/classes/transforms/wvtransformstratifiedqg/a0n.html) matrix component that multiplies $$\tilde{\eta}$$ to compute $$A_0$$.
  + [`A0U`](/classes/transforms/wvtransformstratifiedqg/a0u.html) matrix component that multiplies $$\tilde{u}$$ to compute $$A_0$$.
  + [`A0V`](/classes/transforms/wvtransformstratifiedqg/a0v.html) matrix component that multiplies $$\tilde{v}$$ to compute $$A_0$$.
  + [`A0Z`](/classes/transforms/wvtransformstratifiedqg/a0z.html)
  + [`NA0`](/classes/transforms/wvtransformstratifiedqg/na0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{\eta}$$.
  + [`P0`](/classes/transforms/wvtransformstratifiedqg/p0.html) Preconditioner for F, size(P)=[Nj 1]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`PA0`](/classes/transforms/wvtransformstratifiedqg/pa0.html)
  + [`Q0`](/classes/transforms/wvtransformstratifiedqg/q0.html) Preconditioner for G, size(Q)=[Nj 1]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`UA0`](/classes/transforms/wvtransformstratifiedqg/ua0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{u}$$.
  + [`VA0`](/classes/transforms/wvtransformstratifiedqg/va0.html) matrix component that multiplies $$A_0$$ to compute $$\tilde{v}$$.
+ Geometry and mode indexing
  + [`conjugateDimension`](/classes/transforms/wvtransformstratifiedqg/conjugatedimension.html) assumed conjugate dimension
  + [`dftConjugateIndex`](/classes/transforms/wvtransformstratifiedqg/dftconjugateindex.html) legacy vertically replicated conjugate index
  + [`dftPrimaryIndex`](/classes/transforms/wvtransformstratifiedqg/dftprimaryindex.html) legacy vertically replicated index into the active Fourier storage
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
  + [`kMode_dft`](/classes/transforms/wvtransformstratifiedqg/kmode_dft.html) k mode-number on the DFT grid
  + [`kMode_wv`](/classes/transforms/wvtransformstratifiedqg/kmode_wv.html) k mode number on the WV grid
  + [`klModeNumberFromIndex`](/classes/transforms/wvtransformstratifiedqg/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
  + [`lMode_dft`](/classes/transforms/wvtransformstratifiedqg/lmode_dft.html) l mode-number on the DFT grid
  + [`lMode_wv`](/classes/transforms/wvtransformstratifiedqg/lmode_wv.html) l mode number on the WV grid
  + [`maskForAliasedModes`](/classes/transforms/wvtransformstratifiedqg/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
  + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformstratifiedqg/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
  + [`maskForNyquistModes`](/classes/transforms/wvtransformstratifiedqg/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
  + [`modeNumberFromIndex`](/classes/transforms/wvtransformstratifiedqg/modenumberfromindex.html) Return mode numbers for spectral linear indices.
  + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformstratifiedqg/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
  + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformstratifiedqg/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
  + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformstratifiedqg/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
  + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformstratifiedqg/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
  + [`transformToOmegaAxis`](/classes/transforms/wvtransformstratifiedqg/transformtoomegaaxis.html) transforms in the from (j,kRadial) to omegaAxis
  + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
  + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
  + [`waveModeVerticalStructureAtIndex`](/classes/transforms/wvtransformstratifiedqg/wavemodeverticalstructureatindex.html) Return wave vertical-structure factors at one vertical grid index.
  + [`wvConjugateIndex`](/classes/transforms/wvtransformstratifiedqg/wvconjugateindex.html) legacy vertically replicated WV conjugate index
+ Spectral transforms and operators
  + [`FMatrix`](/classes/transforms/wvtransformstratifiedqg/fmatrix.html) transformation matrix $$F_g$$
  + [`FinvMatrix`](/classes/transforms/wvtransformstratifiedqg/finvmatrix.html) transformation matrix $$F_g^{-1}$$
  + [`GMatrix`](/classes/transforms/wvtransformstratifiedqg/gmatrix.html) transformation matrix $$G_g$$
  + [`GinvMatrix`](/classes/transforms/wvtransformstratifiedqg/ginvmatrix.html) transformation matrix $$G_g^{-1}$$
  + [`PF0`](/classes/transforms/wvtransformstratifiedqg/pf0.html) size(PF,PG)=[Nj x Nz]
  + [`PF0inv`](/classes/transforms/wvtransformstratifiedqg/pf0inv.html) Transformation matrices
  + [`QG0`](/classes/transforms/wvtransformstratifiedqg/qg0.html) Preconditioned G-mode forward transformation
  + [`QG0inv`](/classes/transforms/wvtransformstratifiedqg/qg0inv.html) Preconditioned G-mode inverse transformation
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformstratifiedqg/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformstratifiedqg/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`fastTransform`](/classes/transforms/wvtransformstratifiedqg/fasttransform.html) fast transform object
  + [`hydrostaticTransform`](/classes/transforms/wvtransformstratifiedqg/hydrostatictransform.html)
  + [`spectrumWithFgTransform`](/classes/transforms/wvtransformstratifiedqg/spectrumwithfgtransform.html)
  + [`spectrumWithGgTransform`](/classes/transforms/wvtransformstratifiedqg/spectrumwithggtransform.html)
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformstratifiedqg/transformfromspatialdomainwithfio.html)
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformstratifiedqg/transformfromspatialdomainwithfourier.html)
  + [`transformToKLAxes`](/classes/transforms/wvtransformstratifiedqg/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformstratifiedqg/transformtospatialdomainwithfourieratposition.html)
  + [`transformWithG_wg`](/classes/transforms/wvtransformstratifiedqg/transformwithg_wg.html)
+ Nonlinear flux and forcing internals
  + [`fluxForForcing`](/classes/transforms/wvtransformstratifiedqg/fluxforforcing.html)
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformstratifiedqg/qgpvfluxfromf0.html)
+ Persistence internals
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformstratifiedqg/classrequiredpropertynames.html)
  + [`geometryFromGroup`](/classes/transforms/wvtransformstratifiedqg/geometryfromgroup.html)
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformstratifiedqg/namesofrequiredpropertiesforgeometry.html)
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformstratifiedqg/namesofrequiredpropertiesforrotatingfplane.html)
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformstratifiedqg/namesofrequiredpropertiesfortransform.html)
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformstratifiedqg/namesoftransformvariables.html)
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformstratifiedqg/newnonrequiredpropertynames.html)
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformstratifiedqg/newrequiredpropertynames.html)
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformstratifiedqg/requiredpropertiesforgeometryfromgroup.html)
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformstratifiedqg/requiredpropertiesforrotatingfplanefromgroup.html)
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformstratifiedqg/requiredpropertiesfortransformfromgroup.html)
  + [`transformFromGroup`](/classes/transforms/wvtransformstratifiedqg/transformfromgroup.html)
+ Caches and registries
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformstratifiedqg/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformstratifiedqg/propertyannotationsforrotatingfplane.html)
+ Class internals
  + [`geostrophicComponent`](/classes/transforms/wvtransformstratifiedqg/geostrophiccomponent.html) returns the geostrophic flow component
  + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformstratifiedqg/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
  + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformstratifiedqg/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
  + [`J`](/classes/transforms/wvtransformstratifiedqg/j_.html) j-coordinate matrix
  + [`K`](/classes/transforms/wvtransformstratifiedqg/k_.html) k-coordinate matrix
  + [`K2`](/classes/transforms/wvtransformstratifiedqg/k2.html) squared horizontal wavenumber, $$K2=K^2+L^2$$
  + [`Kh`](/classes/transforms/wvtransformstratifiedqg/kh.html) horizontal wavenumber, $$Kh=\sqrt(K^2+L^2)$$
  + [`L`](/classes/transforms/wvtransformstratifiedqg/l_.html) l-coordinate matrix
  + [`Lr2`](/classes/transforms/wvtransformstratifiedqg/lr2.html) squared Rossby radius
  + [`Nk_dft`](/classes/transforms/wvtransformstratifiedqg/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
  + [`Nkl`](/classes/transforms/wvtransformstratifiedqg/nkl.html) length of the combined kl-wavenumber dimension on the WV grid
  + [`Nl_dft`](/classes/transforms/wvtransformstratifiedqg/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
  + [`X`](/classes/transforms/wvtransformstratifiedqg/x_.html) x-coordinate matrix
  + [`Y`](/classes/transforms/wvtransformstratifiedqg/y_.html) y-coordinate matrix
  + [`Z`](/classes/transforms/wvtransformstratifiedqg/z_.html) z-coordinate matrix
  + [`chebfunForZArray`](/classes/transforms/wvtransformstratifiedqg/chebfunforzarray.html)
  + [`dLnN2`](/classes/transforms/wvtransformstratifiedqg/dlnn2.html) $$\frac{\partial \ln N^2}{\partial z}$$, vertical variation of the log of the squared buoyancy frequency
  + [`dftConjugateIndices2D`](/classes/transforms/wvtransformstratifiedqg/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
  + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformstratifiedqg/dftprimaryindices2d.html) index into the DFT grid of each WV mode
  + [`dk`](/classes/transforms/wvtransformstratifiedqg/dk.html) wavenumber spacing of the $$k$$ axis
  + [`dl`](/classes/transforms/wvtransformstratifiedqg/dl.html) wavenumber spacing of the $$l$$ axis
  + [`f`](/classes/transforms/wvtransformstratifiedqg/f.html) Coriolis parameter
  + [`g`](/classes/transforms/wvtransformstratifiedqg/g.html) gravity of Earth
  + [`geometryFromFile`](/classes/transforms/wvtransformstratifiedqg/geometryfromfile.html)
  + [`h_0`](/classes/transforms/wvtransformstratifiedqg/h_0.html) [Nj 1]
  + [`h_pm`](/classes/transforms/wvtransformstratifiedqg/h_pm.html)
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformstratifiedqg/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isDensityInValidRange`](/classes/transforms/wvtransformstratifiedqg/isdensityinvalidrange.html) checks if the density field is a valid adiabatic re-arrangement of the base state
  + [`isHermitian`](/classes/transforms/wvtransformstratifiedqg/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`kPseudoRadial`](/classes/transforms/wvtransformstratifiedqg/kpseudoradial.html)
  + [`kRadial`](/classes/transforms/wvtransformstratifiedqg/kradial.html) radial (k,l) wavenumber on the WV grid
  + [`k_dft`](/classes/transforms/wvtransformstratifiedqg/k_dft.html) k wavenumber dimension on the DFT grid
  + [`kl`](/classes/transforms/wvtransformstratifiedqg/kl.html) wavenumber dimension
  + [`l_dft`](/classes/transforms/wvtransformstratifiedqg/l_dft.html) l wavenumber dimension on the DFT grid
  + [`maxFg`](/classes/transforms/wvtransformstratifiedqg/maxfg.html)
  + [`maxFw`](/classes/transforms/wvtransformstratifiedqg/maxfw.html)
  + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformstratifiedqg/placeparticlesonisopycnal.html) places Lagrangian particles along a specified isopycnal
  + [`planetaryRadius`](/classes/transforms/wvtransformstratifiedqg/planetaryradius.html) radius of the planetary body
  + [`psi`](/classes/transforms/wvtransformstratifiedqg/psi.html) geostrophic streamfunction
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformstratifiedqg/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`rho0`](/classes/transforms/wvtransformstratifiedqg/rho0.html) , dLnN2
  + [`rotationRate`](/classes/transforms/wvtransformstratifiedqg/rotationrate.html) rotation rate of the planetary body
  + [`setConjugateToUnity`](/classes/transforms/wvtransformstratifiedqg/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
  + [`shouldAntialias`](/classes/transforms/wvtransformstratifiedqg/shouldantialias.html) whether the WV grid includes quadratically aliased wavenumbers
  + [`shouldExcludeConjugates`](/classes/transforms/wvtransformstratifiedqg/shouldexcludeconjugates.html) whether the WV grid excludes redundant Hermitian-conjugate wavenumbers
  + [`shouldExcludeNyquist`](/classes/transforms/wvtransformstratifiedqg/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformstratifiedqg/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformstratifiedqg/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors


---