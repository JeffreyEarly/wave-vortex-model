---
layout: default
title: Adding forcing
parent: User guide
nav_order: 4
mathjax: true
---

# Adding forcing

A `WVTransform` provides analytical linear evolution of its modes. Nonlinear advection, external tendencies, and closures enter through `WVForcing` objects.

## Quick start

By default, a `WVTransform` is initialized with exactly one forcing term: nonlinear advection. Initialize a transform, then call `summarizeForcing` to list its right-hand-side terms:
```matlab
wvt = WVTransformHydrostatic([800e3, 800e3, 4000],[64, 64, 65], N2=@(z) (3*2*pi/3600)^2*exp(2*z/1300),latitude=30);
wvt.summarizeForcing
```

```matlabTextOutput
            Name             IsClosure
    _____________________    _________

    "nonlinear advection"     "false"
 ```

Nonlinear integration also needs a closure to control unresolved small scales. `WVAdaptiveDamping` is a useful first choice. Register it with `addForcing`:

```matlab
wvt.addForcing(WVAdaptiveDamping(wvt));
wvt.summarizeForcing
```

```matlabTextOutput
            Name             IsClosure
    _____________________    _________

    "nonlinear advection"     "false"
    "adaptive damping"        "true"
 ```

The model now includes nonlinear advection and adaptive damping when it advances the transform:
```matlab
model = WVModel(wvt);
model.integrateToTime(wvt.inertialPeriod);
```
and it would include both nonlinear advection and small scale adaptive damping.


## The equations of motion

The equations of motion solved by the non-hydrostatic model, `WVTransformBoussinesq` and `WVTransformConstantStratification` are

$$
\begin{align}
\frac{\partial u}{\partial t} - f v + \frac{1}{\rho_0} \partial_x p =& - \textrm{uNL} + \mathcal{S}_u \\
\frac{\partial v}{\partial t} + f u + \frac{1}{\rho_0}\partial_y p =& - \textrm{vNL} +\mathcal{S}_v   \\
\frac{\partial w}{\partial t}  + \frac{1}{\rho_0}\partial_z p + N^2 \eta =& - \textrm{wNL} +\mathcal{S}_w  \\
\frac{\partial \eta}{\partial t} =& - \textrm{nNL} + \mathcal{S}_\eta  \\
\partial_x u + \partial_y v + \partial_z w =& 0,
\end{align}
$$

where

$$
\begin{bmatrix}
\textrm{uNL} \\
\textrm{vNL} \\
\textrm{wNL} \\
\textrm{nNL} \\
0
\end{bmatrix}
=
\begin{bmatrix}
\mathbf{u} \cdot \nabla u\\
\mathbf{u} \cdot \nabla v \\
\mathbf{u} \cdot \nabla w \\
\mathbf{u} \cdot \nabla \eta + w \eta \partial_z \ln N^2 \\
0
\end{bmatrix}
$$

is the nonlinear advection. For hydrostatic dynamics, the vertical momentum equation effectively vanishes because $$w$$ is determined diagnostically.

For the quasigeostrophic transforms, `WVTransformStratifiedQG` and `WVTransformBarotropicQG`, the equation of motion is the evolution of quasigeostrophic potential vorticity (QGPV),

$$
\frac{\partial q}{\partial t} = - u \frac{\partial q}{\partial x} - v \frac{\partial q}{\partial y} + \mathcal{S}_q
$$

where

$$
q = \frac{\partial v}{\partial x} - \frac{\partial u}{\partial y} - f  \frac{\partial \eta}{\partial z}.
$$

This is also commonly written as a streamfunction, using $\psi = \frac{1}{\rho_0 f} p$, $u=-\frac{\partial \psi}{\partial y}$, $v=\frac{\partial \psi}{\partial x}$, $N^2 \eta =-f\frac{\partial \psi}{\partial z}$ or, equivalently, $\rho=- \frac{\rho_0 f}{g} \frac{\partial \psi}{\partial z}$.

Adding forcing to a transform with `wvt.addForcing()` adds an additional right-hand-side term, $$\mathcal{S}$$.

The total coefficient tendency at the current time is returned by `wvt.nonlinearFlux`:
```matlab
[Fp,Fm,F0] = wvt.nonlinearFlux();
```
which returns the forcing on the wave-vortex coefficients. For the QG transforms, the only forcing is PV
```matlab
F0 = wvt.nonlinearFlux();
```

## Generating waves from pseudo-topography

`WVPseudoTopographicWaveGeneration` projects the bottom-normal velocity from a prescribed horizontally uniform current over upward-positive pseudo-topography onto the model's wave modes. Select a standard tidal constituent with `darwinSymbol`, or supply a custom angular `frequency`.

```matlab
forcing = WVPseudoTopographicWaveGeneration(wvt, ...
    topographicHeight=h, ...
    barotropicVelocityAmplitude=[0.05; 0], ...
    darwinSymbol="M2");
wvt.addForcing(forcing);
```

The supported Darwin symbols are `M2`, `S2`, `N2`, `K1`, and `O1`. If neither frequency option is supplied, M2 is used. Direct `frequency` and `darwinSymbol` options are mutually exclusive.

By default, the generated tendency is projected outside the exact support of any active `WVAdaptiveDamping`. Use `maximumForcedHorizontalWavenumber` and `maximumForcedVerticalMode` to impose manual spectral limits for other closure choices.

## Creating your own forcing

Custom forcing subclasses derive from `WVForcing`, declare one or more `WVForcingType` stages, and override the method corresponding to each declared stage. Physical-space forcing modifies velocity and displacement tendencies before projection. Spectral forcing modifies $$(F_+,F_-,F_0)$$ after projection. Spectral-amplitude forcing updates `Ap`, `Am`, and `A0` directly.

For example, horizontal and vertical spectral damping can be expressed as

$$

and implemented by overriding `addSpectralForcing`. Hydrostatic and nonhydrostatic physical forcing instead override `addHydrostaticSpatialForcing` or `addNonhydrostaticSpatialForcing`. QG forcing uses the potential-vorticity variants of the spatial, spectral, or amplitude interfaces.

The transform validates that a forcing stage is compatible with its dynamics, applies stages in physical–spectral–amplitude order, and uses `priority` to order forcing objects within one stage. See [`WVForcing`](/classes/forcing/wvforcing/) and [`WVForcingType`](/classes/forcing/wvforcing/) before implementing a subclass.
    \begin{align}
        \partial_t A_\pm^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_\pm^{k\ell j} - \nu_z \lambda_j^{-2} A_\pm^{k\ell j} \\
        \partial_t A_0^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_0^{k\ell j} - \nu_z \lambda_j^{-2} A_0^{k\ell j}
    \end{align}
$$
