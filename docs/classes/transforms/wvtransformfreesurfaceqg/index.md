---
layout: default
title: WVTransformFreeSurfaceQG
has_children: false
has_toc: false
mathjax: true
parent: Transforms
grand_parent: Class documentation
nav_order: 7
---

#  WVTransformFreeSurfaceQG

Represent free-surface quasigeostrophic flow in canonical families.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVTransformFreeSurfaceQG < WVTransform</code></pre></div></div>

## Overview

The nonzero-horizontal-wavenumber state is split into generalized-
energy APV coefficients `Ag_q` and boundary-normalized zero-APV
coefficients `Ag_0`. The horizontal mean is represented independently
by real mean-density-anomaly coefficients `Amda`.
APV and MDA select independent mode counts on the same
physical vertical grid. The inherited `Nj` value equals
`apvModeCount`; `mdaModeCount` may differ.
Omitted endpoints use $$g_0=-\int_{-D}^{0}N^2\,dz$$ and
$$g_d=\mathop{\rm Inf}$$. The resulting APV family normally includes
a negative mode. InternalModes retains that mode and uses its signed
Pontryagin pairing for projection; coupled quadratic errors are
positive magnitudes in the induced Hilbert majorant.

Scientific construction solves the InternalModesEVP problems once and
stores every sampled mode and projection operator. Persisted-state
construction supplies those annotated arrays directly and never calls
an InternalModes solver.

```matlab
N2 = @(z) (5.2e-3)^2*exp(2*z/1300);
wvt = WVTransformFreeSurfaceQG([100e3 100e3 4000],[32 32 33],N2Function=N2,latitude=30);
```




## Topics
+ Create and restore a transform
  + [`WVTransformFreeSurfaceQG`](/classes/transforms/wvtransformfreesurfaceqg/wvtransformfreesurfaceqg.html) Create a free-surface QG transform scientifically or directly.
  + [`assessVerticalResolution`](/classes/transforms/wvtransformfreesurfaceqg/assessverticalresolution.html) Assess vertical-mode accuracy and the active-endpoint horizontal limit.
  + [`waveVortexTransformFromFile`](/classes/transforms/wvtransformfreesurfaceqg/wavevortextransformfromfile.html) Restore a free-surface QG transform from persisted arrays.
+ Initialize the flow
  + General initialization
    + [`addRandomFlow`](/classes/transforms/wvtransformfreesurfaceqg/addrandomflow.html) add randomized flow to the existing state
    + [`initFromNetCDFFile`](/classes/transforms/wvtransformfreesurfaceqg/initfromnetcdffile.html) initialize the flow from a NetCDF file
    + [`initWithGaussianEddy`](/classes/transforms/wvtransformfreesurfaceqg/initwithgaussianeddy.html) Initialize a balanced, vertically shifted Gaussian eddy.
    + [`initWithRandomFlow`](/classes/transforms/wvtransformfreesurfaceqg/initwithrandomflow.html) initialize with a random flow state
    + [`removeAll`](/classes/transforms/wvtransformfreesurfaceqg/removeall.html) removes all energy from the model
+ Evaluate physical fields
  + On the model grid
    + Density and displacement
      + [`eta`](/classes/transforms/wvtransformfreesurfaceqg/eta.html) Reconstructed isopycnal displacement including MDA.
      + [`rho_nm0`](/classes/transforms/wvtransformfreesurfaceqg/rho_nm0.html) Reference no-motion density profile, `[Nz 1]`, in $$\mathrm{kg\,m^{-3}}$$.
    + Vorticity and geostrophic fields
      + [`psi`](/classes/transforms/wvtransformfreesurfaceqg/psi.html) Reconstructed geostrophic streamfunction.
      + [`qgpv`](/classes/transforms/wvtransformfreesurfaceqg/qgpv.html) Reconstructed APV field.
    + Velocity
      + [`u`](/classes/transforms/wvtransformfreesurfaceqg/u.html) Reconstructed x velocity.
      + [`v`](/classes/transforms/wvtransformfreesurfaceqg/v.html) Reconstructed y velocity.
  + Registered variables
    + [`hasVariableWithName`](/classes/transforms/wvtransformfreesurfaceqg/hasvariablewithname.html) Test whether state variables are registered by name.
    + [`summarizeVariables`](/classes/transforms/wvtransformfreesurfaceqg/summarizevariables.html) Print a table of registered state variables and cache status.
    + [`variableNames`](/classes/transforms/wvtransformfreesurfaceqg/variablenames.html) Return the names of all registered state variables.
    + [`variableWithName`](/classes/transforms/wvtransformfreesurfaceqg/variablewithname.html) Compute or retrieve one or more registered transform variables.
  + Isopycnal utilities
    + [`placeParticlesOnIsopycnal`](/classes/transforms/wvtransformfreesurfaceqg/placeparticlesonisopycnal.html) Return particle depths on the isopycnal identified by a no-motion depth.
  + At arbitrary positions
    + [`variableAtPositionWithName`](/classes/transforms/wvtransformfreesurfaceqg/variableatpositionwithname.html) Access dynamical variables at arbitrary positions in the domain.
+ Save transform state
  + [`writeToFile`](/classes/transforms/wvtransformfreesurfaceqg/writetofile.html) Write the complete free-surface QG scientific representation.
+ Inspect wave-vortex coefficients
  + Stored coefficients
    + [`Ag_0`](/classes/transforms/wvtransformfreesurfaceqg/ag_0.html) Boundary-normalized zero-APV coefficients in inverse seconds.
    + [`Ag_q`](/classes/transforms/wvtransformfreesurfaceqg/ag_q.html) Generalized-energy APV coefficients in inverse seconds.
    + [`Amda`](/classes/transforms/wvtransformfreesurfaceqg/amda.html) Real mean-density-anomaly displacement coefficients in meters.
  + Family contract
    + [`coefficientStateAnnotations`](/classes/transforms/wvtransformfreesurfaceqg/coefficientstateannotations.html) Return the canonical free-surface coefficient-family order.
    + [`coefficientStateVariableNamesForPersistence`](/classes/transforms/wvtransformfreesurfaceqg/coefficientstatevariablenamesforpersistence.html) Return physically present canonical coefficient variable names.
  + Coefficient evolution
    + [`t0`](/classes/transforms/wvtransformfreesurfaceqg/t0.html) Reference time for the stored wave phases, in seconds.
    + [`t`](/classes/transforms/wvtransformfreesurfaceqg/t.html) Current transform time in seconds.
    + [`coefficientTendency`](/classes/transforms/wvtransformfreesurfaceqg/coefficienttendency.html) Evaluate the family-keyed free-surface QG tendency.
+ Inspect the domain
  + Spectral grid
    + Compact grid arrays
      + [`K`](/classes/transforms/wvtransformfreesurfaceqg/k_.html) X-direction angular-wavenumber array in $$\mathrm{rad\,m^{-1}}$$ with shape `[Nj Nkl]`.
      + [`L`](/classes/transforms/wvtransformfreesurfaceqg/l_.html) Y-direction angular-wavenumber array in $$\mathrm{rad\,m^{-1}}$$ with shape `[Nj Nkl]`.
      + [`J`](/classes/transforms/wvtransformfreesurfaceqg/j_.html) Dimensionless vertical-mode index array with shape `[Nj Nkl]`.
      + [`kljGrid`](/classes/transforms/wvtransformfreesurfaceqg/kljgrid.html) Return spectral-coordinate arrays in wave-vortex layout.
    + Horizontal wavenumber geometry
      + [`Kh`](/classes/transforms/wvtransformfreesurfaceqg/kh.html) Horizontal angular-wavenumber magnitude on the coefficient grid.
      + [`K2`](/classes/transforms/wvtransformfreesurfaceqg/k2.html) Squared horizontal angular wavenumber on the coefficient grid.
    + Resolution and shape
      + [`Nj`](/classes/transforms/wvtransformfreesurfaceqg/nj.html) Number of retained vertical modes.
      + [`Nkl`](/classes/transforms/wvtransformfreesurfaceqg/nkl.html) Number of retained compact horizontal-wavenumber columns.
      + [`spectralMatrixSize`](/classes/transforms/wvtransformfreesurfaceqg/spectralmatrixsize.html) Shape of a wave-vortex coefficient array.
      + [`effectiveHorizontalGridResolution`](/classes/transforms/wvtransformfreesurfaceqg/effectivehorizontalgridresolution.html) returns the effective grid resolution in meters
      + [`effectiveVerticalGridResolution`](/classes/transforms/wvtransformfreesurfaceqg/effectiveverticalgridresolution.html) returns the effective vertical grid resolution in meters
      + [`effectiveJMax`](/classes/transforms/wvtransformfreesurfaceqg/effectivejmax.html) Largest active vertical-mode index.
      + [`summarizeDegreesOfFreedom`](/classes/transforms/wvtransformfreesurfaceqg/summarizedegreesoffreedom.html) Summarize the spatial grid and active spectral degrees of freedom.
    + Free-surface modes and operators
      + [`activeEndpoint`](/classes/transforms/wvtransformfreesurfaceqg/activeendpoint.html) Numeric endpoint codes, surface `1` then bottom `2`.
      + [`activeEndpointCount`](/classes/transforms/wvtransformfreesurfaceqg/activeendpointcount.html) Number of finite endpoint accelerations.
      + [`apvEndpointResponse`](/classes/transforms/wvtransformfreesurfaceqg/apvendpointresponse.html) APV endpoint responses for each active endpoint and page.
      + [`apvEquivalentDepth`](/classes/transforms/wvtransformfreesurfaceqg/apvequivalentdepth.html) APV equivalent depths.
      + [`apvF`](/classes/transforms/wvtransformfreesurfaceqg/apvf.html) Sampled APV F modes.
      + [`apvFForward`](/classes/transforms/wvtransformfreesurfaceqg/apvfforward.html) APV F projection matrix.
      + [`apvFSourcePairing`](/classes/transforms/wvtransformfreesurfaceqg/apvfsourcepairing.html) APV F source-pairing operator.
      + [`apvG`](/classes/transforms/wvtransformfreesurfaceqg/apvg.html) Sampled APV G modes.
      + [`apvGForward`](/classes/transforms/wvtransformfreesurfaceqg/apvgforward.html) APV G projection matrix.
      + [`apvGSourcePairing`](/classes/transforms/wvtransformfreesurfaceqg/apvgsourcepairing.html) APV G source-pairing operator.
      + [`apvGramError`](/classes/transforms/wvtransformfreesurfaceqg/apvgramerror.html) Worst retained APV Gram error.
      + [`apvGramTolerance`](/classes/transforms/wvtransformfreesurfaceqg/apvgramtolerance.html) Normalized Gram tolerance used for APV selection.
      + [`apvMode`](/classes/transforms/wvtransformfreesurfaceqg/apvmode.html) Ordinal APV family coordinate.
      + [`apvModeCount`](/classes/transforms/wvtransformfreesurfaceqg/apvmodecount.html) Number of retained APV modes.
      + [`apvModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/apvmodenumber.html) Physical APV mode labels.
      + [`apvMu`](/classes/transforms/wvtransformfreesurfaceqg/apvmu.html) APV inversion eigenvalues for each horizontal page.
      + [`apvRoundTripError`](/classes/transforms/wvtransformfreesurfaceqg/apvroundtriperror.html) Worst retained APV sampled round-trip error.
      + [`apvZeroAPVLimitingEndpoint`](/classes/transforms/wvtransformfreesurfaceqg/apvzeroapvlimitingendpoint.html) Active endpoint limiting the APV/zero-APV product error.
      + [`apvZeroAPVLimitingModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/apvzeroapvlimitingmodenumber.html) APV physical mode label limiting the APV/zero-APV product error.
      + [`apvZeroAPVQuadraticError`](/classes/transforms/wvtransformfreesurfaceqg/apvzeroapvquadraticerror.html) APV/zero-APV quadratic-product error at maximum horizontal wavenumber.
      + [`g0`](/classes/transforms/wvtransformfreesurfaceqg/g0.html) Effective surface acceleration; omitted default is `-integral(N2,-Lz,0)`.
      + [`gd`](/classes/transforms/wvtransformfreesurfaceqg/gd.html) Effective bottom acceleration; omitted default is `Inf`.
      + [`kNonzero`](/classes/transforms/wvtransformfreesurfaceqg/knonzero.html) X wavenumber associated with `klNonzero`.
      + [`khNonzero`](/classes/transforms/wvtransformfreesurfaceqg/khnonzero.html) Horizontal-wavenumber magnitude associated with `klNonzero`.
      + [`khUnique`](/classes/transforms/wvtransformfreesurfaceqg/khunique.html) Distinct positive horizontal-wavenumber pages.
      + [`klNonzero`](/classes/transforms/wvtransformfreesurfaceqg/klnonzero.html) Original full-`kl` indices retained at positive horizontal wavenumber.
      + [`klNonzeroKhUniqueIndex`](/classes/transforms/wvtransformfreesurfaceqg/klnonzerokhuniqueindex.html) One-based map from `klNonzero` to `khUnique`.
      + [`lNonzero`](/classes/transforms/wvtransformfreesurfaceqg/lnonzero.html) Y wavenumber associated with `klNonzero`.
      + [`mdaEquivalentDepth`](/classes/transforms/wvtransformfreesurfaceqg/mdaequivalentdepth.html) MDA equivalent depths.
      + [`mdaF`](/classes/transforms/wvtransformfreesurfaceqg/mdaf.html) Sampled MDA F modes.
      + [`mdaG`](/classes/transforms/wvtransformfreesurfaceqg/mdag.html) Sampled MDA G modes.
      + [`mdaGForward`](/classes/transforms/wvtransformfreesurfaceqg/mdagforward.html) MDA G projection matrix.
      + [`mdaGramError`](/classes/transforms/wvtransformfreesurfaceqg/mdagramerror.html) Retained MDA Gram error.
      + [`mdaGramTolerance`](/classes/transforms/wvtransformfreesurfaceqg/mdagramtolerance.html) Normalized Gram tolerance used for MDA selection.
      + [`mdaMode`](/classes/transforms/wvtransformfreesurfaceqg/mdamode.html) Ordinal MDA family coordinate.
      + [`mdaModeCount`](/classes/transforms/wvtransformfreesurfaceqg/mdamodecount.html) Number of retained MDA modes.
      + [`mdaModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/mdamodenumber.html) Physical MDA mode labels.
      + [`mdaRoundTripError`](/classes/transforms/wvtransformfreesurfaceqg/mdaroundtriperror.html) Retained MDA sampled round-trip error.
      + [`minimumRelativeMuSeparation`](/classes/transforms/wvtransformfreesurfaceqg/minimumrelativemuseparation.html) Minimum relative APV inversion-eigenvalue separation.
      + [`modeSelectionMethod`](/classes/transforms/wvtransformfreesurfaceqg/modeselectionmethod.html) Persisted mode-selection method identifier.
      + [`sourceEndpoint`](/classes/transforms/wvtransformfreesurfaceqg/sourceendpoint.html) Matching source-endpoint coordinate codes.
      + [`verticalGridCoordinate`](/classes/transforms/wvtransformfreesurfaceqg/verticalgridcoordinate.html) Coordinate in which the vertical-grid rule is native.
      + [`verticalGridKind`](/classes/transforms/wvtransformfreesurfaceqg/verticalgridkind.html) Shared vertical-grid design kind, `chebyshevLobatto`.
      + [`verticalQuadratureWeights`](/classes/transforms/wvtransformfreesurfaceqg/verticalquadratureweights.html) Shared positive physical quadrature weights.
      + [`zeroAPVF`](/classes/transforms/wvtransformfreesurfaceqg/zeroapvf.html) Sampled boundary-normalized zero-APV F pages.
      + [`zeroAPVFPairing`](/classes/transforms/wvtransformfreesurfaceqg/zeroapvfpairing.html) Zero-APV F source-pairing matrices.
      + [`zeroAPVG`](/classes/transforms/wvtransformfreesurfaceqg/zeroapvg.html) Sampled boundary-normalized zero-APV G pages.
      + [`zeroAPVGPairing`](/classes/transforms/wvtransformfreesurfaceqg/zeroapvgpairing.html) Zero-APV G source-pairing matrices.
      + [`zeroAPVGramReciprocalCondition`](/classes/transforms/wvtransformfreesurfaceqg/zeroapvgramreciprocalcondition.html) Pagewise zero-APV generalized-energy reciprocal condition.
      + [`zeroAPVGramRelativeSeparation`](/classes/transforms/wvtransformfreesurfaceqg/zeroapvgramrelativeseparation.html) Pagewise zero-APV generalized-energy relative separation.
      + [`zeroAPVSourceSolve`](/classes/transforms/wvtransformfreesurfaceqg/zeroapvsourcesolve.html) Pagewise zero-APV source-solve matrices.
    + Wavenumber spacing
      + [`dk`](/classes/transforms/wvtransformfreesurfaceqg/dk.html) Spacing of the x-direction angular-wavenumber axis.
      + [`dl`](/classes/transforms/wvtransformfreesurfaceqg/dl.html) Spacing of the y-direction angular-wavenumber axis.
    + Vertical modes and scaling
      + [`h_0`](/classes/transforms/wvtransformfreesurfaceqg/h_0.html) Geostrophic equivalent-depth scale for each vertical mode.
    + Compact grid vectors
      + [`k`](/classes/transforms/wvtransformfreesurfaceqg/k.html) Compact `Nkl`-by-1 x-wavenumber vector in $$\mathrm{rad\,m^{-1}}$$.
      + [`l`](/classes/transforms/wvtransformfreesurfaceqg/l.html) Compact `Nkl`-by-1 y-wavenumber vector in $$\mathrm{rad\,m^{-1}}$$.
      + [`j`](/classes/transforms/wvtransformfreesurfaceqg/j.html) Dimensionless `Nj`-by-1 vertical-mode index vector.
  + Spatial grid
    + Domain dimensions
      + [`Lx`](/classes/transforms/wvtransformfreesurfaceqg/lx.html) Periodic domain length in the x direction.
      + [`Ly`](/classes/transforms/wvtransformfreesurfaceqg/ly.html) Periodic domain length in the y direction.
      + [`Lz`](/classes/transforms/wvtransformfreesurfaceqg/lz.html) Vertical domain depth in meters.
    + Resolution and shape
      + [`Nx`](/classes/transforms/wvtransformfreesurfaceqg/nx.html) Number of spatial grid points in the x direction.
      + [`Ny`](/classes/transforms/wvtransformfreesurfaceqg/ny.html) Number of spatial grid points in the y direction.
      + [`Nz`](/classes/transforms/wvtransformfreesurfaceqg/nz.html) Number of vertical spatial grid points.
      + [`spatialMatrixSize`](/classes/transforms/wvtransformfreesurfaceqg/spatialmatrixsize.html) Shape of a gridded physical-space field.
    + Coordinate arrays
      + [`X`](/classes/transforms/wvtransformfreesurfaceqg/x_.html) Gridded x-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`Y`](/classes/transforms/wvtransformfreesurfaceqg/y_.html) Gridded y-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`Z`](/classes/transforms/wvtransformfreesurfaceqg/z_.html) Gridded vertical-coordinate array in meters with shape `[Nx Ny Nz]`.
      + [`xyzGrid`](/classes/transforms/wvtransformfreesurfaceqg/xyzgrid.html) Return the three-dimensional spatial coordinate arrays.
    + Coordinate axes
      + [`x`](/classes/transforms/wvtransformfreesurfaceqg/x.html) Periodic x-coordinate axis in meters.
      + [`y`](/classes/transforms/wvtransformfreesurfaceqg/y.html) Periodic y-coordinate axis in meters.
      + [`z`](/classes/transforms/wvtransformfreesurfaceqg/z.html) Three-dimensional vertical-coordinate array in meters.
    + Quadrature and integration
      + [`z_int`](/classes/transforms/wvtransformfreesurfaceqg/z_int.html) Vertical quadrature weights in meters.
  + Physical environment
    + Stratification and reference density
      + [`N2`](/classes/transforms/wvtransformfreesurfaceqg/n2.html) Buoyancy frequency squared sampled on the vertical grid.
      + [`N2Function`](/classes/transforms/wvtransformfreesurfaceqg/n2function.html) Function returning buoyancy frequency squared at requested depths.
      + [`buoyancyPeriod`](/classes/transforms/wvtransformfreesurfaceqg/buoyancyperiod.html) Shortest buoyancy period in seconds.
      + [`dLnN2`](/classes/transforms/wvtransformfreesurfaceqg/dlnn2.html) $$\partial_z \ln N^2$$, vertical derivative of the logarithm of squared buoyancy frequency
      + [`rho0`](/classes/transforms/wvtransformfreesurfaceqg/rho0.html) Boussinesq reference density in kilograms per cubic meter.
      + [`rhoFunction`](/classes/transforms/wvtransformfreesurfaceqg/rhofunction.html) Function returning the no-motion density profile at requested depths.
    + Planetary rotation
      + [`beta`](/classes/transforms/wvtransformfreesurfaceqg/beta.html) Meridional gradient of the Coriolis parameter.
      + [`f`](/classes/transforms/wvtransformfreesurfaceqg/f.html) Coriolis parameter in radians per second.
      + [`inertialPeriod`](/classes/transforms/wvtransformfreesurfaceqg/inertialperiod.html) Inertial period in seconds.
      + [`latitude`](/classes/transforms/wvtransformfreesurfaceqg/latitude.html) Central latitude of the rotating domain in degrees north.
      + [`planetaryRadius`](/classes/transforms/wvtransformfreesurfaceqg/planetaryradius.html) Radius of the rotating planetary body in meters.
      + [`rotationRate`](/classes/transforms/wvtransformfreesurfaceqg/rotationrate.html) Planetary rotation rate in radians per second.
    + Gravity
      + [`g`](/classes/transforms/wvtransformfreesurfaceqg/g.html) Gravitational acceleration in meters per second squared.
  + Transform configuration
    + [`isHydrostatic`](/classes/transforms/wvtransformfreesurfaceqg/ishydrostatic.html) Whether the transform uses the hydrostatic approximation.
    + [`shouldAntialias`](/classes/transforms/wvtransformfreesurfaceqg/shouldantialias.html) Whether the spectral grid excludes modes that alias quadratic products.
+ Extend a transform
  + Flow components
    + [`addFlowComponent`](/classes/transforms/wvtransformfreesurfaceqg/addflowcomponent.html) add a flow component and its standard variables
    + [`addPrimaryFlowComponent`](/classes/transforms/wvtransformfreesurfaceqg/addprimaryflowcomponent.html) add a primary flow component, automatically added to the flow
  + Operations and variables
    + [`addOperation`](/classes/transforms/wvtransformfreesurfaceqg/addoperation.html) Register one or more operations and their output variables.
    + [`operationWithName`](/classes/transforms/wvtransformfreesurfaceqg/operationwithname.html) retrieve a WVOperation by name
    + [`removeOperation`](/classes/transforms/wvtransformfreesurfaceqg/removeoperation.html) Remove the exact registered operation and its cached outputs.
+ Manage forcing and closures
  + Configure forcing
    + [`addForcing`](/classes/transforms/wvtransformfreesurfaceqg/addforcing.html) Add forcing or closure objects to this transform.
    + [`setForcing`](/classes/transforms/wvtransformfreesurfaceqg/setforcing.html) Replace the complete forcing registry.
    + [`removeForcing`](/classes/transforms/wvtransformfreesurfaceqg/removeforcing.html) Remove the exact registered forcing objects.
    + [`removeAllForcing`](/classes/transforms/wvtransformfreesurfaceqg/removeallforcing.html) Remove every forcing and closure from this transform.
  + Inspect forcing and closures
    + [`forcing`](/classes/transforms/wvtransformfreesurfaceqg/forcing.html) array of WVForcing objects
    + [`forcingNames`](/classes/transforms/wvtransformfreesurfaceqg/forcingnames.html) Return forcing and closure names in application order.
    + [`forcingWithName`](/classes/transforms/wvtransformfreesurfaceqg/forcingwithname.html) Return registered forcing objects by name.
    + [`hasForcingWithName`](/classes/transforms/wvtransformfreesurfaceqg/hasforcingwithname.html) Test whether forcing objects are registered by name.
    + [`hasClosure`](/classes/transforms/wvtransformfreesurfaceqg/hasclosure.html) Whether a closure is currently attached to the transform.
  + Summarize forcing
    + [`summarizeForcing`](/classes/transforms/wvtransformfreesurfaceqg/summarizeforcing.html) Print a table of registered forcing and closure objects.
+ Analyze the flow
  + Spectra
    + Spectral fields
      + [`kAxis`](/classes/transforms/wvtransformfreesurfaceqg/kaxis.html) Centered `Nx`-by-1 x-wavenumber axis in $$\mathrm{rad\,m^{-1}}$$.
      + [`lAxis`](/classes/transforms/wvtransformfreesurfaceqg/laxis.html) Centered `Ny`-by-1 y-wavenumber axis in $$\mathrm{rad\,m^{-1}}$$.
      + [`transformToKLAxes`](/classes/transforms/wvtransformfreesurfaceqg/transformtoklaxes.html) transforms in the spectral domain from (j,kl) to (kAxis,lAxis,j)
      + [`crossSpectrumWithFgTransform`](/classes/transforms/wvtransformfreesurfaceqg/crossspectrumwithfgtransform.html) Compute a real modal cross-spectrum using the F-basis transform.
      + [`crossSpectrumWithGgTransform`](/classes/transforms/wvtransformfreesurfaceqg/crossspectrumwithggtransform.html) Compute a real modal cross-spectrum using the G-basis transform.
      + [`spectrumWithFgTransform`](/classes/transforms/wvtransformfreesurfaceqg/spectrumwithfgtransform.html) Compute a modal autospectrum using the F-basis transform.
      + [`spectrumWithGgTransform`](/classes/transforms/wvtransformfreesurfaceqg/spectrumwithggtransform.html) Compute a modal autospectrum using the G-basis transform.
    + Radial wavenumber
      + [`kRadial`](/classes/transforms/wvtransformfreesurfaceqg/kradial.html) radial (k,l) wavenumber on the WV grid
      + [`transformToRadialWavenumber`](/classes/transforms/wvtransformfreesurfaceqg/transformtoradialwavenumber.html) transforms in the spectral domain from (j,kl) to (j,kRadial)
  + Flow diagnostics
    + [`hasMeanPressureDifference`](/classes/transforms/wvtransformfreesurfaceqg/hasmeanpressuredifference.html) Diagnose an MDA mean-pressure difference between the boundaries.
  + Density validity
    + [`isDensityInValidRange`](/classes/transforms/wvtransformfreesurfaceqg/isdensityinvalidrange.html) Test whether total density remains within the no-motion density range.
+ Differentiate and integrate fields
  + [`diffX`](/classes/transforms/wvtransformfreesurfaceqg/diffx.html) Differentiate a gridded field in the periodic x direction.
  + [`diffY`](/classes/transforms/wvtransformfreesurfaceqg/diffy.html) Differentiate a gridded field in the periodic y direction.
  + [`diffZF`](/classes/transforms/wvtransformfreesurfaceqg/diffzf.html) Differentiate an F-grid field with respect to z.
  + [`diffZG`](/classes/transforms/wvtransformfreesurfaceqg/diffzg.html) Differentiate a G-grid field with respect to z.
  + [`intZF`](/classes/transforms/wvtransformfreesurfaceqg/intzf.html) Return the first antiderivative of an F-representation.
  + [`intZG`](/classes/transforms/wvtransformfreesurfaceqg/intzg.html) Return the bottom-zero first antiderivative of a G-representation.
+ Inspect flow components
  + Registered and combined components
    + [`flowComponents`](/classes/transforms/wvtransformfreesurfaceqg/flowcomponents.html) All registered physical and diagnostic flow components.
    + [`flowComponentNames`](/classes/transforms/wvtransformfreesurfaceqg/flowcomponentnames.html) retrieve the names of all available variables
    + [`flowComponentWithName`](/classes/transforms/wvtransformfreesurfaceqg/flowcomponentwithname.html) retrieve a WVFlowComponent by name
    + [`totalFlowComponent`](/classes/transforms/wvtransformfreesurfaceqg/totalflowcomponent.html) Combined view of all primary flow components.
  + Primary flow components
    + [`primaryFlowComponents`](/classes/transforms/wvtransformfreesurfaceqg/primaryflowcomponents.html) Primary flow components that partition the active coefficient state.
    + [`primaryFlowComponentNames`](/classes/transforms/wvtransformfreesurfaceqg/primaryflowcomponentnames.html) retrieve the names of all available variables
    + [`primaryFlowComponentWithName`](/classes/transforms/wvtransformfreesurfaceqg/primaryflowcomponentwithname.html) retrieve a WVPrimaryFlowComponent by name
  + Summarize flow components
    + [`summarizeFlowComponents`](/classes/transforms/wvtransformfreesurfaceqg/summarizeflowcomponents.html) Print a table of registered primary and diagnostic components.
+ Convert representations
  + Physical fields and coefficients
    + [`reconstructSpectralState`](/classes/transforms/wvtransformfreesurfaceqg/reconstructspectralstate.html) Reconstruct compact spectral streamfunction, displacement, and APV.
    + [`transformMDABack`](/classes/transforms/wvtransformfreesurfaceqg/transformmdaback.html) Reconstruct horizontal-mean displacement from the MDA family.
    + [`transformMDAForward`](/classes/transforms/wvtransformfreesurfaceqg/transformmdaforward.html) Project horizontal-mean displacement onto the MDA family.
    + [`transformStateBack`](/classes/transforms/wvtransformfreesurfaceqg/transformstateback.html) Reconstruct sampled APV and active endpoint anomalies.
    + [`transformStateForward`](/classes/transforms/wvtransformfreesurfaceqg/transformstateforward.html) Project sampled APV first and residual endpoint anomalies second.
+ Create a related transform
  + [`spectralVariableWithResolution`](/classes/transforms/wvtransformfreesurfaceqg/spectralvariablewithresolution.html) create a new variable with different resolution
  + [`waveVortexTransformWithDoubleResolution`](/classes/transforms/wvtransformfreesurfaceqg/wavevortextransformwithdoubleresolution.html) create a new WVTransform with double resolution
  + [`waveVortexTransformWithResolution`](/classes/transforms/wvtransformfreesurfaceqg/wavevortextransformwithresolution.html) Create the same transform family at a new resolution.
+ Analyze energy
  + Energy summaries
    + [`summarizeEnergyContent`](/classes/transforms/wvtransformfreesurfaceqg/summarizeenergycontent.html) displays a summary of the energy content of the fluid
    + [`summarizeModeEnergy`](/classes/transforms/wvtransformfreesurfaceqg/summarizemodeenergy.html) List the most energetic modes
  + Total energy
    + [`totalEnergy`](/classes/transforms/wvtransformfreesurfaceqg/totalenergy.html) Total energy computed from wave-vortex coefficients.
    + [`totalEnergySpatiallyIntegrated`](/classes/transforms/wvtransformfreesurfaceqg/totalenergyspatiallyintegrated.html) Total energy computed from physical-space fields.
  + Component energy
    + [`totalEnergyOfFlowComponent`](/classes/transforms/wvtransformfreesurfaceqg/totalenergyofflowcomponent.html) Compute the energy carried by one flow component.
+ Get package information
  + [`version`](/classes/transforms/wvtransformfreesurfaceqg/version.html) Installed WaveVortexModel version.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Geometry and mode indexing
  + DFT and WV layout metadata
    + [`Nk_dft`](/classes/transforms/wvtransformfreesurfaceqg/nk_dft.html) length of the k-wavenumber dimension on the DFT grid
    + [`Nl_dft`](/classes/transforms/wvtransformfreesurfaceqg/nl_dft.html) length of the l-wavenumber dimension on the DFT grid
    + [`conjugateDimension`](/classes/transforms/wvtransformfreesurfaceqg/conjugatedimension.html) assumed conjugate dimension
    + [`dftConjugateIndices2D`](/classes/transforms/wvtransformfreesurfaceqg/dftconjugateindices2d.html) index into the DFT grid of the conjugate of each WV mode
    + [`dftPrimaryIndices2D`](/classes/transforms/wvtransformfreesurfaceqg/dftprimaryindices2d.html) index into the DFT grid of each WV mode
    + [`indicesOfFourierConjugates`](/classes/transforms/wvtransformfreesurfaceqg/indicesoffourierconjugates.html) a matrix of linear indices of the conjugate
    + [`k_dft`](/classes/transforms/wvtransformfreesurfaceqg/k_dft.html) k wavenumber dimension on the DFT grid
    + [`kl`](/classes/transforms/wvtransformfreesurfaceqg/kl.html) wavenumber dimension
    + [`l_dft`](/classes/transforms/wvtransformfreesurfaceqg/l_dft.html) l wavenumber dimension on the DFT grid
    + [`shouldExcludeConjugates`](/classes/transforms/wvtransformfreesurfaceqg/shouldexcludeconjugates.html) whether the WV grid excludes redundant Hermitian-conjugate wavenumbers
    + [`shouldExcludeNyquist`](/classes/transforms/wvtransformfreesurfaceqg/shouldexcludenyquist.html) whether the WV grid includes Nyquist wavenumbers
  + Linear-index conversion
    + [`indexFromKLModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/indexfromklmodenumber.html) return the linear index into k_wv and l_wv from a mode number
    + [`indexFromModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/indexfrommodenumber.html) return the linear index into a spectral matrix given (k,l,j)
    + [`klModeNumberFromIndex`](/classes/transforms/wvtransformfreesurfaceqg/klmodenumberfromindex.html) return mode number from a linear index into a WV matrix
    + [`modeNumberFromIndex`](/classes/transforms/wvtransformfreesurfaceqg/modenumberfromindex.html) Return mode numbers for spectral linear indices.
  + Layout conversion
    + [`indicesFromDFTGridToWVGrid`](/classes/transforms/wvtransformfreesurfaceqg/indicesfromdftgridtowvgrid.html) indices to convert from DFT to WV grid
    + [`indicesFromWVGridToDFTGrid`](/classes/transforms/wvtransformfreesurfaceqg/indicesfromwvgridtodftgrid.html) indices to convert from WV to DFT grid
    + [`transformFromDFTGridToWVGrid`](/classes/transforms/wvtransformfreesurfaceqg/transformfromdftgridtowvgrid.html) convert from DFT to WV grid
    + [`transformFromSpatialDomainToDFTGrid`](/classes/transforms/wvtransformfreesurfaceqg/transformfromspatialdomaintodftgrid.html) transform from $$(x,y,z)$$ to $$(k,l,z)$$ on the DFT grid
    + [`transformFromWVGridToDFTGrid`](/classes/transforms/wvtransformfreesurfaceqg/transformfromwvgridtodftgrid.html) convert from a WV to DFT grid
    + [`transformToSpatialDomainFromDFTGrid`](/classes/transforms/wvtransformfreesurfaceqg/transformtospatialdomainfromdftgrid.html) transform from $$(k,l,z)$$ on the DFT grid to $$(x,y,z)$$
    + [`transformToSpatialDomainFromDFTGridAtPosition`](/classes/transforms/wvtransformfreesurfaceqg/transformtospatialdomainfromdftgridatposition.html) transform from $$(k,l)$$ on the DFT grid to $$(x,y)$$ at any position
  + Masks and Hermitian bookkeeping
    + [`isHermitian`](/classes/transforms/wvtransformfreesurfaceqg/ishermitian.html) Check if the matrix is Hermitian. Report errors.
    + [`maskForAliasedModes`](/classes/transforms/wvtransformfreesurfaceqg/maskforaliasedmodes.html) returns a mask with locations of modes that will alias with a quadratic multiplication.
    + [`maskForConjugateFourierCoefficients`](/classes/transforms/wvtransformfreesurfaceqg/maskforconjugatefouriercoefficients.html) a mask indicate the components that are redundant conjugates
    + [`maskForNyquistModes`](/classes/transforms/wvtransformfreesurfaceqg/maskfornyquistmodes.html) returns a mask with locations of modes that are not fully resolved
    + [`setConjugateToUnity`](/classes/transforms/wvtransformfreesurfaceqg/setconjugatetounity.html) set the conjugate of the wavenumber (iK,iL) to 1
  + Mode numbers and validity
    + [`isValidConjugateKLModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/isvalidconjugateklmodenumber.html) return a boolean indicating whether (k,l) is a valid conjugate WV mode number
    + [`isValidConjugateModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid conjugate mode number
    + [`isValidKLModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/isvalidklmodenumber.html) return a boolean indicating whether (k,l) is a valid WV mode number
    + [`isValidModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
    + [`isValidPrimaryKLModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/isvalidprimaryklmodenumber.html) return a boolean indicating whether (k,l) is a valid primary (non-conjugate) WV mode number
    + [`isValidPrimaryModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid primary (non-conjugate) mode number
    + [`kMode_dft`](/classes/transforms/wvtransformfreesurfaceqg/kmode_dft.html) k mode-number on the DFT grid
    + [`kMode_wv`](/classes/transforms/wvtransformfreesurfaceqg/kmode_wv.html) k mode number on the WV grid
    + [`lMode_dft`](/classes/transforms/wvtransformfreesurfaceqg/lmode_dft.html) l mode-number on the DFT grid
    + [`lMode_wv`](/classes/transforms/wvtransformfreesurfaceqg/lmode_wv.html) l mode number on the WV grid
    + [`primaryKLModeNumberFromKLModeNumber`](/classes/transforms/wvtransformfreesurfaceqg/primaryklmodenumberfromklmodenumber.html) takes any valid WV mode number and returns the primary mode number
  + Additional geometry utilities
    + [`quadraticAliasingLimitingModeNumberI`](/classes/transforms/wvtransformfreesurfaceqg/quadraticaliasinglimitingmodenumberi.html) First physical mode label in the limiting product.
    + [`quadraticAliasingLimitingModeNumberJ`](/classes/transforms/wvtransformfreesurfaceqg/quadraticaliasinglimitingmodenumberj.html) Second physical mode label in the limiting product.
+ Spectral transforms and operators
  + [`P0`](/classes/transforms/wvtransformfreesurfaceqg/p0.html) Preconditioner for F, size(P)=[Nj 1]. F*u = uhat, (PF)*u = P*uhat, so ubar==P*uhat
  + [`PF0`](/classes/transforms/wvtransformfreesurfaceqg/pf0.html) size(PF,PG)=[Nj x Nz]
  + [`PF0inv`](/classes/transforms/wvtransformfreesurfaceqg/pf0inv.html) Transformation matrices
  + [`Q0`](/classes/transforms/wvtransformfreesurfaceqg/q0.html) Preconditioner for G, size(Q)=[Nj 1]. G*eta = etahat, (QG)*eta = Q*etahat, so etabar==Q*etahat.
  + [`QG0`](/classes/transforms/wvtransformfreesurfaceqg/qg0.html) dimensionless preconditioned G-mode forward transformation
  + [`QG0inv`](/classes/transforms/wvtransformfreesurfaceqg/qg0inv.html) dimensionless preconditioned G-mode inverse transformation
  + [`degreesOfFreedomForComplexMatrix`](/classes/transforms/wvtransformfreesurfaceqg/degreesoffreedomforcomplexmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`degreesOfFreedomForRealMatrix`](/classes/transforms/wvtransformfreesurfaceqg/degreesoffreedomforrealmatrix.html) a matrix with the number of degrees-of-freedom at each entry
  + [`fastTransform`](/classes/transforms/wvtransformfreesurfaceqg/fasttransform.html) fast transform object
  + [`transformFromSpatialDomainWithFio`](/classes/transforms/wvtransformfreesurfaceqg/transformfromspatialdomainwithfio.html)
  + [`transformFromSpatialDomainWithFourier`](/classes/transforms/wvtransformfreesurfaceqg/transformfromspatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourier`](/classes/transforms/wvtransformfreesurfaceqg/transformtospatialdomainwithfourier.html)
  + [`transformToSpatialDomainWithFourierAtPosition`](/classes/transforms/wvtransformfreesurfaceqg/transformtospatialdomainwithfourieratposition.html)
  + [`transformWithG_wg`](/classes/transforms/wvtransformfreesurfaceqg/transformwithg_wg.html)
+ Class internals
  + [`chebfunForZArray`](/classes/transforms/wvtransformfreesurfaceqg/chebfunforzarray.html)
  + [`maxFg`](/classes/transforms/wvtransformfreesurfaceqg/maxfg.html)
  + [`maxFw`](/classes/transforms/wvtransformfreesurfaceqg/maxfw.html)
  + [`muTolerance`](/classes/transforms/wvtransformfreesurfaceqg/mutolerance.html) Relative singularity tolerance used for APV inversion.
  + [`projectQuasigeostrophicSpatialTendency`](/classes/transforms/wvtransformfreesurfaceqg/projectquasigeostrophicspatialtendency.html) Project physical QG tendencies into canonical coefficient families.
  + [`quadraticAliasingError`](/classes/transforms/wvtransformfreesurfaceqg/quadraticaliasingerror.html) Coupled quadratic-aliasing error at the selected APV count.
  + [`quadraticAliasingLimitingChannel`](/classes/transforms/wvtransformfreesurfaceqg/quadraticaliasinglimitingchannel.html) Product channel limiting the selected APV prefix.
  + [`quadraticAliasingTolerance`](/classes/transforms/wvtransformfreesurfaceqg/quadraticaliasingtolerance.html) Coupled quadratic-aliasing tolerance used for APV selection.
  + [`quadraturePointsForStratifiedFlow`](/classes/transforms/wvtransformfreesurfaceqg/quadraturepointsforstratifiedflow.html) return the quadrature points for a given stratification
  + [`quasigeostrophicSpatialState`](/classes/transforms/wvtransformfreesurfaceqg/quasigeostrophicspatialstate.html) Reconstruct the physical state used by QG spatial forcing.
  + [`throwErrorIfDensityViolation`](/classes/transforms/wvtransformfreesurfaceqg/throwerrorifdensityviolation.html) checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state
  + [`verticalProjectionOperatorsWithRigidLid`](/classes/transforms/wvtransformfreesurfaceqg/verticalprojectionoperatorswithrigidlid.html) return the normalized projection operators with prefactors
+ Persistence internals
  + [`classRequiredPropertyNames`](/classes/transforms/wvtransformfreesurfaceqg/classrequiredpropertynames.html)
  + [`geometryFromGroup`](/classes/transforms/wvtransformfreesurfaceqg/geometryfromgroup.html)
  + [`namesOfRequiredPropertiesForGeometry`](/classes/transforms/wvtransformfreesurfaceqg/namesofrequiredpropertiesforgeometry.html)
  + [`namesOfRequiredPropertiesForRotatingFPlane`](/classes/transforms/wvtransformfreesurfaceqg/namesofrequiredpropertiesforrotatingfplane.html)
  + [`namesOfRequiredPropertiesForTransform`](/classes/transforms/wvtransformfreesurfaceqg/namesofrequiredpropertiesfortransform.html)
  + [`newNonrequiredPropertyNames`](/classes/transforms/wvtransformfreesurfaceqg/newnonrequiredpropertynames.html)
  + [`newRequiredPropertyNames`](/classes/transforms/wvtransformfreesurfaceqg/newrequiredpropertynames.html)
  + [`requiredPropertiesForGeometryFromGroup`](/classes/transforms/wvtransformfreesurfaceqg/requiredpropertiesforgeometryfromgroup.html)
  + [`requiredPropertiesForRotatingFPlaneFromGroup`](/classes/transforms/wvtransformfreesurfaceqg/requiredpropertiesforrotatingfplanefromgroup.html)
  + [`transformFromGroup`](/classes/transforms/wvtransformfreesurfaceqg/transformfromgroup.html) Construct directly from the complete annotated representation.
+ Caches and registries
  + [`propertyAnnotationsForGeometry`](/classes/transforms/wvtransformfreesurfaceqg/propertyannotationsforgeometry.html) return array of CAPropertyAnnotations initialized by default
  + [`propertyAnnotationsForRotatingFPlane`](/classes/transforms/wvtransformfreesurfaceqg/propertyannotationsforrotatingfplane.html)


---