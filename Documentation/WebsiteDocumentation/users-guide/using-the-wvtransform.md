---
layout: default
title: Using WVTransform
parent: User guide
mathjax: true
nav_order: 2
has_toc: true
---

# Using `WVTransform`

A `WVTransform` represents a fluid state in physical and wave–vortex coordinates. The transform family determines the dynamical approximation, vertical structure, and flow components available to the state.

## Choose a transform

| Transform | Use it for |
| --- | --- |
| [`WVTransformConstantStratification`](/classes/transforms/wvtransformconstantstratification/) | Hydrostatic or nonhydrostatic flow with constant buoyancy frequency. |
| [`WVTransformHydrostatic`](/classes/transforms/wvtransformhydrostatic/) | Hydrostatic flow with variable stratification. |
| [`WVTransformBoussinesq`](/classes/transforms/wvtransformboussinesq/) | Nonhydrostatic flow with variable stratification. |
| [`WVTransformStratifiedQG`](/classes/transforms/wvtransformstratifiedqg/) | Three-dimensional stratified quasigeostrophic flow. |
| [`WVTransformFreeSurfaceQG`](/classes/transforms/wvtransformfreesurfaceqg/) | Free-surface QG modal construction, reconstruction, and durable persistence; the nonlinear RHS is deferred. |
| [`WVTransformBarotropicQG`](/classes/transforms/wvtransformbarotropicqg/) | Two-dimensional equivalent-barotropic quasigeostrophic flow. |

All rotating transforms accept latitude in either hemisphere for $$5 \leq \lvert\mathrm{latitude}\rvert \leq 85$$ degrees.

## Construct a transform

Every transform takes the domain size and grid size as its first two arguments. Wave-bearing three-dimensional transforms store `Ap`, `Am`, and `A0`; the legacy QG transforms store their geostrophic state in `A0`. `WVTransformFreeSurfaceQG` instead stores APV, zero-APV, and mean-density-anomaly state in `Ag_q`, `Ag_0`, and `Amda`.

### Constant stratification

Supply the constant buoyancy frequency `N0`. The default is nonhydrostatic; set `isHydrostatic=true` to use the hydrostatic approximation.

```matlab
Lxyz = [100e3 100e3 4000];
Nxyz = [64 64 65];
N0 = 3*2*pi/3600;

wvt = WVTransformConstantStratification(Lxyz,Nxyz,N0=N0,latitude=30);
wvtHydrostatic = WVTransformConstantStratification(Lxyz,Nxyz,N0=N0,latitude=30,isHydrostatic=true);
```

### Variable stratification

Supply either `N2Function`, returning the squared buoyancy frequency, or `rhoFunction`, returning the mean density profile on $$[-L_z,0]$$.

```matlab
N0 = 3*2*pi/3600;
Lgm = 1300;
N2 = @(z) N0*N0*exp(2*z/Lgm);

wvtHydrostatic = WVTransformHydrostatic(Lxyz,Nxyz,N2Function=N2,latitude=30);
wvtBoussinesq = WVTransformBoussinesq(Lxyz,Nxyz,N2Function=N2,latitude=30);
wvtQG = WVTransformStratifiedQG(Lxyz,Nxyz,N2Function=N2,latitude=30);
```

### Free-surface QG

Supply the same stratification inputs together with optional endpoint accelerations `g0` and `gd`. The transform chooses the largest APV/MDA mode prefix certified on the supplied `z` grid unless `Nj` is requested explicitly. A finite endpoint activates one row of the boundary-normalized `Ag_0` family; an infinite endpoint is inactive.

```matlab
wvtFreeSurfaceQG = WVTransformFreeSurfaceQG(Lxyz,Nxyz,N2Function=N2,latitude=30,g0=0.02,gd=Inf);
```

This milestone supports scientific construction, projection and reconstruction, snapshots, model-output persistence, and restart. Nonlinear tendency evaluation is intentionally unavailable until the free-surface QG RHS is added.

### Equivalent-barotropic QG

The two-dimensional transform takes horizontal dimensions and an equivalent depth `h`:

```matlab
wvtBarotropic = WVTransformBarotropicQG([100e3 100e3],[64 64],h=0.8,latitude=30);
```

## Use the transform grids

The transform chooses grids compatible with its spectral representation. Access coordinate vectors through `wvt.x`, `wvt.y`, and, for three-dimensional transforms, `wvt.z`. The arrays `wvt.X`, `wvt.Y`, and `wvt.Z` have the transform's spatial matrix shape.

Horizontal grids are evenly spaced and periodic. Constant-stratification transforms use the sine/cosine vertical grid, while variable-stratification transforms use quadrature points determined by the vertical modes. Use the grids supplied by the transform rather than constructing replacements.

## Initialize a fluid state

Initialization methods follow a common naming convention:

- `initWith...` clears `Ap`, `Am`, and `A0` before initializing the requested state.
- `set...` replaces one flow component while preserving the others.
- `add...` superimposes a flow component on the existing state.
- `removeAll...` removes the named component.

### Project physical fields

For wave-bearing transforms, `initWithUVEta` and `initWithUVRho` project gridded velocity and displacement or density-anomaly fields onto the wave–vortex basis. Inputs must use the transform's spatial grid and boundary conditions.

```matlab
U = 0.2*exp(wvt.Z/100);
V = zeros(wvt.spatialMatrixSize);
eta = zeros(wvt.spatialMatrixSize);
wvt.initWithUVEta(U,V,eta);
```

This projection can also decompose output from another numerical model when its fields have been placed on compatible grids with compatible stratification and boundary conditions.

### Initialize analytical components

The component-specific methods initialize internal waves, inertial oscillations, geostrophic motions, and mean-density anomalies. For example, initialize one internal wave by integer horizontal and vertical mode numbers:

```matlab
[omega,k,l] = wvt.initWithWaveModes(kMode=10,lMode=0,j=1,phi=0,u=0.2,sign=1);
period = 2*pi/omega;
```

Use `initWithRandomFlow` for a deterministic or random collection of supported components, and use the component-specific API pages for spectral initialization options.

## Evaluate physical fields

Registered state variables can be accessed through dot syntax:

```matlab
u = wvt.u;
rho = wvt.rho;
```

Requesting related variables together avoids repeating shared calculations:

```matlab
[u,v,w,rho] = wvt.variableWithName('u','v','w','rho');
```

Use `wvt.summarizeVariables` to list the registered variables, their dimensions, and units. Depending on the transform, variables include velocity, density, pressure, sea-surface fields, quasigeostrophic potential vorticity, energy diagnostics, and nonlinear fluxes.

For periodic off-grid queries, use `variableAtPositionWithName` with `linear` or `spline` interpolation:

```matlab
xq = [0 10e3 20e3];
yq = [0 15e3 30e3];
zq = [-100 -300 -500];
[uq,vq] = wvt.variableAtPositionWithName(xq,yq,zq,'u','v',interpolationMethod='spline');
```

Horizontal query coordinates wrap periodically. The returned arrays retain the query shape.

## Continue from here

- [Wavenumbers, modes, and indices](/users-guide/wavenumber-modes-and-indices.html) explains primary and conjugate mode conventions.
- [Adding forcing](/users-guide/adding-forcing.html) prepares a transform for nonlinear integration.
- [Reading and writing files](/users-guide/reading-and-writing-to-file.html) covers transform persistence and model restart.
- [`WVTransform` API](/classes/transforms/wvtransform/) lists all state variables, diagnostics, and initialization methods.
