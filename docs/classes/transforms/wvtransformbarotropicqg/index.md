---
layout: default
title: WVTransformBarotropicQG
has_children: false
has_toc: false
mathjax: true
parent: Transforms
grand_parent: Class documentation
nav_order: 4
---

#  WVTransformBarotropicQG

A transform for modeling single-layer quasigeostrophic flow


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransformBarotropicQG < <a href="/classes/wvtransform/" title="WVTransform">WVTransform</a></code></pre></div></div>

## Overview

This is a two-dimensional, single-layer which may be interpreted as
the sea-surface height. The 'h' parameter is the equivalent depth,
and 0.80 m is a typical value for the first baroclinic mode.

```matlab
Lxy = 50e3;
Nxy = 256;
latitude = 25;
wvt = WVTransformSingleMode([Lxy, Lxy], [Nxy, Nxy], h=0.8, latitude=latitude);
```





## Topics
+ Initialization
  + [`WVTransformBarotropicQG`](/classes/transforms/wvtransformbarotropicqg/wvtransformbarotropicqg.html) create geometry for 2D barotropic flow
+ Domain attributes
  + Spatial grid
    + [`Lx`](/classes/transforms/wvtransformbarotropicqg/lx.html) length of the x-dimension
    + [`Ly`](/classes/transforms/wvtransformbarotropicqg/ly.html) length of the y-dimension
    + [`Nx`](/classes/transforms/wvtransformbarotropicqg/nx.html) number of grid points in the x-dimension
    + [`Ny`](/classes/transforms/wvtransformbarotropicqg/ny.html) number of grid points in the y-dimension
    + [`fastTransform`](/classes/transforms/wvtransformbarotropicqg/fasttransform.html) fast transform object
    + [`x`](/classes/transforms/wvtransformbarotropicqg/x_.html) dimension
    + [`y`](/classes/transforms/wvtransformbarotropicqg/y_.html) dimension
  + DFT grid
    + [`Nk_dft`](/classes/transforms/wvtransformbarotropicqg/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
    + [`Nl_dft`](/classes/transforms/wvtransformbarotropicqg/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
    + [`conjugateDimension`](/classes/transforms/wvtransformbarotropicqg/conjugatedimension.html) assumed conjugate dimension
    + [`kMode_dft`](/classes/transforms/wvtransformbarotropicqg/kmode_dft.html) k mode-number on the DFT grid
    + [`k_dft`](/classes/transforms/wvtransformbarotropicqg/k_dft.html) k wavenumber dimension on the DFT grid
    + [`lMode_dft`](/classes/transforms/wvtransformbarotropicqg/lmode_dft.html) l mode-number on the DFT grid
    + [`l_dft`](/classes/transforms/wvtransformbarotropicqg/l_dft.html) l wavenumber dimension on the DFT grid
  + WV grid
    + [`Nkl`](/classes/transforms/wvtransformbarotropicqg/nkl.html) length of the combined kl-wavenumber dimension on the WV grid
    + [`dftConjugateIndex`](/classes/transforms/wvtransformbarotropicqg/dftconjugateindex.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftConjugateIndices2D`](/classes/transforms/wvtransformbarotropicqg/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftPrimaryIndex`](/classes/transforms/wvtransformbarotropicqg/dftprimaryindex.html) index into the DFT grid of each WV mode
    + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformbarotropicqg/dftprimaryindices2d.html) index into the DFT grid of each WV mode
    + [`dk`](/classes/transforms/wvtransformbarotropicqg/dk.html) wavenumber spacing of the $$k$$ axis
    + [`dl`](/classes/transforms/wvtransformbarotropicqg/dl.html) wavenumber spacing of the $$l$$ axis
    + [`k`](/classes/transforms/wvtransformbarotropicqg/k_.html) wavenumber dimension on the WV grid
    + [`kMode_wv`](/classes/transforms/wvtransformbarotropicqg/kmode_wv.html) k mode number on the WV grid
    + [`kRadial`](/classes/transforms/wvtransformbarotropicqg/kradial.html) radial (k,l) wavenumber on the WV grid
    + [`kl`](/classes/transforms/wvtransformbarotropicqg/kl.html) wavenumber dimension
    + [`l`](/classes/transforms/wvtransformbarotropicqg/l_.html) wavenumber dimension on the WV grid
    + [`lMode_wv`](/classes/transforms/wvtransformbarotropicqg/lmode_wv.html) l mode number on the WV grid
    + [`shouldAntialias`](/classes/transforms/wvtransformbarotropicqg/shouldantialias.html) whether the WV grid includes quadratically aliased wavenumbers
    + [`shouldExcludeNyquist`](/classes/transforms/wvtransformbarotropicqg/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
    + [`shouldExludeConjugates`](/classes/transforms/wvtransformbarotropicqg/shouldexludeconjugates.html) whether the WV grid includes wavenumbers that are Hermitian conjugates
    + [`wvConjugateIndex`](/classes/transforms/wvtransformbarotropicqg/wvconjugateindex.html) index into the WV mode that matches the dftConjugateIndices
+ Initial conditions
  + Geostrophic Motions
    + [`initWithGeostrophicStreamfunction`](/classes/transforms/wvtransformbarotropicqg/initwithgeostrophicstreamfunction.html) initialize with a geostrophic streamfunction
    + [`setGeostrophicStreamfunction`](/classes/transforms/wvtransformbarotropicqg/setgeostrophicstreamfunction.html) set a geostrophic streamfunction
    + [`addGeostrophicStreamfunction`](/classes/transforms/wvtransformbarotropicqg/addgeostrophicstreamfunction.html) add a geostrophic streamfunction to existing geostrophic motions
    + [`setGeostrophicModes`](/classes/transforms/wvtransformbarotropicqg/setgeostrophicmodes.html) set amplitudes of the given geostrophic modes
    + [`addGeostrophicModes`](/classes/transforms/wvtransformbarotropicqg/addgeostrophicmodes.html) add amplitudes of the given geostrophic modes
    + [`removeAllGeostrophicMotions`](/classes/transforms/wvtransformbarotropicqg/removeallgeostrophicmotions.html) remove all geostrophic motions
+ Utility function
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformbarotropicqg/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformbarotropicqg/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformbarotropicqg/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
  + [`isHermitian`](/classes/transforms/wvtransformbarotropicqg/ishermitian.html) Check if the matrix is Hermitian. Report errors.
  + [`setConjugateToUnity`](/classes/transforms/wvtransformbarotropicqg/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
+ Properties
  + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformbarotropicqg/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
+ Primary flow components
  + [`geostrophicComponent`](/classes/transforms/wvtransformbarotropicqg/geostrophiccomponent.html) returns the geostrophic flow component
+ Energetics
  + [`geostrophicEnergy`](/classes/transforms/wvtransformbarotropicqg/geostrophicenergy.html) total energy of the geostrophic flow
  + [`geostrophicKineticEnergy`](/classes/transforms/wvtransformbarotropicqg/geostrophickineticenergy.html) kinetic energy of the geostrophic flow
  + [`geostrophicPotentialEnergy`](/classes/transforms/wvtransformbarotropicqg/geostrophicpotentialenergy.html) potential energy of the geostrophic flow
+ Index gymnastics
  + [`indexFromKLModeNumber`](/classes/transforms/wvtransformbarotropicqg/indexfromklmodenumber.html) return the linear index into k_wv and l_wv from a mode number
  + [`indicesFromDFTGridToWVGrid`](/classes/transforms/wvtransformbarotropicqg/indicesfromdftgridtowvgrid.html) indices to convert from DFT to WV grid
  + [`indicesFromWVGridToDFTGrid`](/classes/transforms/wvtransformbarotropicqg/indicesfromwvgridtodftgrid.html) indices to convert from WV to DFT grid
  + [`indicesFromWVGridToFFTWGrid`](/classes/transforms/wvtransformbarotropicqg/indicesfromwvgridtofftwgrid.html) indices to convert from WV to DFT grid
  + [`isValidConjugateKLModeNumber`](/classes/transforms/wvtransformbarotropicqg/isvalidconjugateklmodenumber.html) return a boolean indicating whether (k,l) is a valid conjugate WV mode number
  + [`isValidKLModeNumber`](/classes/transforms/wvtransformbarotropicqg/isvalidklmodenumber.html) return a boolean indicating whether (k,l) is a valid WV mode number
  + [`isValidPrimaryKLModeNumber`](/classes/transforms/wvtransformbarotropicqg/isvalidprimaryklmodenumber.html) return a boolean indicating whether (k,l) is a valid primary (non-conjugate) WV mode number
  + [`klModeNumberFromIndex`](/classes/transforms/wvtransformbarotropicqg/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
  + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformbarotropicqg/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
+ Masks
  + [`maskForAliasedModes`](/classes/transforms/wvtransformbarotropicqg/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
  + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformbarotropicqg/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
  + [`maskForNyquistModes`](/classes/transforms/wvtransformbarotropicqg/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
+ Developer
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformbarotropicqg/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
+ Operations
  + Grid transformation
    + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformbarotropicqg/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
    + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformbarotropicqg/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
  + Fourier transformation
    + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformbarotropicqg/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
    + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformbarotropicqg/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
    + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformbarotropicqg/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
  + Transformations
    + [`transformToKLAxes`](/classes/transforms/wvtransformbarotropicqg/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
    + [`transformToRadialWavenumber`](/classes/transforms/wvtransformbarotropicqg/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
+ Other
  + [`A0N`](/classes/transforms/wvtransformbarotropicqg/a0n.html) 
  + [`A0Z`](/classes/transforms/wvtransformbarotropicqg/a0z.html) 
  + [`F0`](/classes/transforms/wvtransformbarotropicqg/f0.html) 
  + [`Fpv`](/classes/transforms/wvtransformbarotropicqg/fpv.html) 
  + [`J`](/classes/transforms/wvtransformbarotropicqg/j_.html) 
  + [`K`](/classes/transforms/wvtransformbarotropicqg/k.html) 
  + [`K2`](/classes/transforms/wvtransformbarotropicqg/k2.html) 
  + [`Kh`](/classes/transforms/wvtransformbarotropicqg/kh.html) 
  + [`L`](/classes/transforms/wvtransformbarotropicqg/l.html) 
  + [`Lr2`](/classes/transforms/wvtransformbarotropicqg/lr2.html) 
  + [`Lz`](/classes/transforms/wvtransformbarotropicqg/lz.html) 
  + [`NA0`](/classes/transforms/wvtransformbarotropicqg/na0.html) 
  + [`Nj`](/classes/transforms/wvtransformbarotropicqg/nj.html) 
  + [`PA0`](/classes/transforms/wvtransformbarotropicqg/pa0.html) 
  + [`UA0`](/classes/transforms/wvtransformbarotropicqg/ua0.html) 
  + [`VA0`](/classes/transforms/wvtransformbarotropicqg/va0.html) 
  + [`X`](/classes/transforms/wvtransformbarotropicqg/x.html) 
  + [`Y`](/classes/transforms/wvtransformbarotropicqg/y.html) 
  + [`Z`](/classes/transforms/wvtransformbarotropicqg/z.html) 
  + [`beta`](/classes/transforms/wvtransformbarotropicqg/beta.html) 
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformbarotropicqg/classrequiredpropertynames.html) 
  + [`diffX`](/classes/transforms/wvtransformbarotropicqg/diffx.html) 
  + [`diffY`](/classes/transforms/wvtransformbarotropicqg/diffy.html) 
  + [`effectiveJMax`](/classes/transforms/wvtransformbarotropicqg/effectivejmax.html) 
  + [`enstrophyFluxFromF0`](/classes/transforms/wvtransformbarotropicqg/enstrophyfluxfromf0.html) 
  + [`f`](/classes/transforms/wvtransformbarotropicqg/f.html) 
  + [`fluxForForcing`](/classes/transforms/wvtransformbarotropicqg/fluxforforcing.html) 
  + [`g`](/classes/transforms/wvtransformbarotropicqg/g.html) 
  + [`geometryFromFile`](/classes/transforms/wvtransformbarotropicqg/geometryfromfile.html) 
  + [`geometryFromGroup`](/classes/transforms/wvtransformbarotropicqg/geometryfromgroup.html) 
  + [`h`](/classes/transforms/wvtransformbarotropicqg/h.html) 
  + [`h_0`](/classes/transforms/wvtransformbarotropicqg/h_0.html) [Nj 1]
  + [`indexFromModeNumber`](/classes/transforms/wvtransformbarotropicqg/indexfrommodenumber.html) 
  + [`inertialPeriod`](/classes/transforms/wvtransformbarotropicqg/inertialperiod.html) 
  + [`j`](/classes/transforms/wvtransformbarotropicqg/j.html) 
  + [`kAxis`](/classes/transforms/wvtransformbarotropicqg/kaxis.html) 
  + [`klGrid`](/classes/transforms/wvtransformbarotropicqg/klgrid.html) 
  + [`kljGrid`](/classes/transforms/wvtransformbarotropicqg/kljgrid.html) 
  + [`lAxis`](/classes/transforms/wvtransformbarotropicqg/laxis.html) 
  + [`latitude`](/classes/transforms/wvtransformbarotropicqg/latitude.html) 
  + [`maxFg`](/classes/transforms/wvtransformbarotropicqg/maxfg.html) 
  + [`modeNumberFromIndex`](/classes/transforms/wvtransformbarotropicqg/modenumberfromindex.html) 
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformbarotropicqg/namesofrequiredpropertiesforgeometry.html) 
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformbarotropicqg/namesofrequiredpropertiesforrotatingfplane.html) 
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformbarotropicqg/namesofrequiredpropertiesfortransform.html) 
  + [`namesOfTransformVariables`](/classes/transforms/wvtransformbarotropicqg/namesoftransformvariables.html) 
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformbarotropicqg/newnonrequiredpropertynames.html) 
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformbarotropicqg/newrequiredpropertynames.html) 
  + [`planetaryRadius`](/classes/transforms/wvtransformbarotropicqg/planetaryradius.html) 
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformbarotropicqg/propertyannotationsforrotatingfplane.html) 
  + [`qgpvFluxFromF0`](/classes/transforms/wvtransformbarotropicqg/qgpvfluxfromf0.html) 
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformbarotropicqg/requiredpropertiesforgeometryfromgroup.html) This guy ignores Nz, because we will just use the default
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformbarotropicqg/requiredpropertiesforrotatingfplanefromgroup.html) 
  + [`requiredPropertiesForTransformFromGroup`](/classes/transforms/wvtransformbarotropicqg/requiredpropertiesfortransformfromgroup.html) 
  + [`rotationRate`](/classes/transforms/wvtransformbarotropicqg/rotationrate.html) 
  + [`setSSH`](/classes/transforms/wvtransformbarotropicqg/setssh.html) 
  + [`spatialMatrixSize`](/classes/transforms/wvtransformbarotropicqg/spatialmatrixsize.html) 
  + [`spectralMatrixSize`](/classes/transforms/wvtransformbarotropicqg/spectralmatrixsize.html) 
  + [`totalEnstrophy`](/classes/transforms/wvtransformbarotropicqg/totalenstrophy.html) 
  + [`totalEnstrophySpatiallyIntegrated`](/classes/transforms/wvtransformbarotropicqg/totalenstrophyspatiallyintegrated.html) 
  + [`transformFromGroup`](/classes/transforms/wvtransformbarotropicqg/transformfromgroup.html) 
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformbarotropicqg/transformfromspatialdomainwithfourier.html) 
  + [`transformQGPVToWaveVortex`](/classes/transforms/wvtransformbarotropicqg/transformqgpvtowavevortex.html) 
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformbarotropicqg/transformtospatialdomainwithfourier.html) 
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformbarotropicqg/transformtospatialdomainwithfourieratposition.html) 
  + [`xyGrid`](/classes/transforms/wvtransformbarotropicqg/xygrid.html) 


---