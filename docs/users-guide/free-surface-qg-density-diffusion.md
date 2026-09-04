---
layout: default
title: Free-surface QG density diffusion
parent: User guide
nav_order: 9
mathjax: true
---

# Free-surface QG density diffusion

The developmental free-surface QG model uses one canonical transform, `WVTransformFreeSurfaceQG`. Its state consists of interior APV coefficients `Ag_q`, boundary-normalized zero-APV coefficients `Ag_0`, and independent mean-density-anomaly coefficients `Amda`. Diffusion and integrator selection preserve every coefficient family.

## Register diffusion and select an integrator

```matlab
N2 = @(z) (5.2e-3)^2*exp(2*z/1300);
wvt = WVTransformFreeSurfaceQG([500e3 500e3 4000],[24 24 65],N2Function=N2);
wvt.addForcing(WVVerticalDiffusivity(wvt,kappa_z=1e-5));
model = WVModel(wvt);
model.setupIntegrator(integratorType="exponential");
```

`WVVerticalDiffusivity` owns the Galerkin diffusion generators. Its ordinary forcing callback and exponential evolution use the same generators. Setting `kappa_z=0` leaves the represented state unchanged and makes the diffusion tendency zero. Omitting the forcing avoids diffusion construction entirely.

The exponential path uses `WVDensityDiffusionIntegrator` to evolve linear density diffusion and the strict seasonal source from `WVSeasonalSurfaceAnomalyForcing` analytically. ETDRK4 evaluates the remaining forcings explicitly. Its adaptive error estimate uses reconstructed RMS QGPV, buoyancy, speed, and endpoint displacement. Diffusion eigenmodes and their numerical diagnostics are constructed only when requested by this path.

Ordinary adaptive integration remains the default. It evaluates diffusion through the forcing callback and may need small steps for stiff diffusion. Ordinary fixed integration also evaluates that callback, and its automatic step selection includes a conservative diffusion bound. Supplying `deltaT` above that bound raises `WVModel:DiffusionTimeStep`. The bound controls fast diffusion modes; accuracy may require a smaller step. Switching integrators retains the registered forcings and canonical state:

```matlab
model.setupIntegrator(integratorType="adaptive");
```

The current diffusion discretization requires both endpoints active. Nondiffusive transforms and physical diagnostics support all endpoint combinations. The exponential integrator currently requires canonical free-surface QG with `WVVerticalDiffusivity`; it is not a general ODE integrator. It supports passive output observers, but does not integrate particles or other coupled observer state.

## Use the same metrics for inventories and budgets

```matlab
inventory = wvt.quadraticDiagnostics();
budget = wvt.quadraticDiagnostics(tendency=wvt.coefficientTendency());
```

`inventory.totalEnergy`, `wvt.totalEnergy`, and `wvt.totalEnergySpatiallyIntegrated` use the same positive physical inventory: kinetic energy, interior potential energy, and surface gravitational energy. Energy is horizontally averaged and vertically integrated, with units of m3 s-2. This is distinct from signed generalized energy used to normalize the canonical modes.

`inventory.potentialEnstrophy` and `wvt.totalPotentialEnstrophy` evaluate the half-integral of squared full QGPV, including the horizontal-mean contribution from `Amda`, in m s-2. Supplying a coefficient tendency adds corresponding `Tendency` fields, such as `totalEnergyTendency` and `potentialEnstrophyTendency`. The optional second output resolves contributions in `klNonzero` order and excludes the separately included horizontal mean. These metrics require neither diffusion nor an exponential integrator.

Adaptive damping exposes its actual horizontal and vertical contributions for the same budget calculation:

```matlab
damping = WVAdaptiveDamping(wvt,apvCutoffFraction=0.7);
wvt.addForcing(damping);
[horizontal,vertical] = damping.quasigeostrophicDampingContributions(wvt);
horizontalBudget = wvt.quadraticDiagnostics(tendency=horizontal);
verticalBudget = wvt.quadraticDiagnostics(tendency=vertical);
```

`apvCutoffFraction` controls the APV-mode damping onset and is saved with the forcing. The default `NaN` retains the standard cutoff. The sum of these contributions is the tendency used by the damping callback. Horizontal damping acts on APV and active-endpoint coefficients; vertical-mode damping acts on APV coefficients. Both leave `Amda` unchanged.

Canonical snapshots store scientific modes, coefficients, and forcing configuration. Quadrature metrics, diffusion generators, and eigenmodes are rebuildable caches. After restoring a transform, select exponential integration again through `setupIntegrator` when needed. Earlier beta diffusion-transform APIs and checkpoints are not retained.
