---
layout: default
title: Adding forcing
parent: User guide
nav_order: 4
mathjax: true
---

# Adding forcing

`WVModel` advances a transform with nonlinear advection by default. External tendencies and closures enter through `WVForcing` objects, while analytical linear evolution is available when nonlinear interactions should be omitted.

The [Forcing reference](/classes/forcing/) summarizes the supplied physical and spectral tendencies. The [Closures reference](/classes/forcing/closures/) compares the available small-scale closures and their principal controls.

## Quick start

By default, a `WVTransform` is initialized with exactly one forcing term: nonlinear advection. Initialize a transform, then call `summarizeForcing` to list its right-hand-side terms:
```matlab
wvt = WVTransformHydrostatic([800e3,800e3,4000],[64,64,65],N2Function=@(z)(3*2*pi/3600)^2*exp(2*z/1300),latitude=30);
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

`WVModel` now advances the transform with both nonlinear advection and small-scale adaptive damping.

Prescribed forcings and closures use the same registration mechanism. For example, `WVFixedAmplitudeForcing` can hold selected wave-vortex coefficients at specified values, while traditional horizontal and vertical damping apply fixed viscosity or diffusivity. The class reference documents each forcing's supported geometry, configuration, and diagnostic scales.


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

This is also commonly written using the streamfunction $$\psi = p/(\rho_0 f)$$, for which $$u=-\partial_y \psi$$, $$v=\partial_x \psi$$, and $$N^2 \eta =-f\partial_z \psi$$ or, equivalently, $$\rho=- (\rho_0 f/g) \partial_z \psi$$.

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

`WVPseudoTopographicWaveGeneration` projects the bottom-normal velocity from a prescribed horizontally uniform current over upward-positive pseudo-topography onto the model's wave modes. The linearized bottom condition is

$$
g_b=\mathbf{U}_{\mathrm{bt}}\cdot\nabla_H h.
$$

The forcing projects this velocity onto each wave mode with its bottom-pressure structure and modal-energy normalization, converts the result to the stored `Ap` and `Am` representation, and leaves `A0` unchanged. Select a standard tidal constituent with `darwinSymbol`, or supply a custom angular `frequency`.

```matlab
forcing = WVPseudoTopographicWaveGeneration(wvt,topographicHeight=h,barotropicVelocityAmplitude=[0.05; 0],darwinSymbol="M2");
wvt.addForcing(forcing);
```

The supported Darwin symbols are `M2`, `S2`, `N2`, `K1`, and `O1`. If neither frequency option is supplied, M2 is used. Direct `frequency` and `darwinSymbol` options are mutually exclusive.

By default, the generated tendency is projected outside the exact support of any active `WVAdaptiveDamping`. Use `maximumForcedHorizontalWavenumber` and `maximumForcedVerticalMode` to impose manual spectral limits for other closure choices.

See [`WVPseudoTopographicWaveGeneration`](/classes/forcing/wvpseudotopographicwavegeneration/) for the ramp, Fourier projection, phase conversion, and energy-work relation.

## Adding beta-plane PV advection

`WVBetaPlanePVAdvection` adds the right-hand-side QGPV tendency

$$
\left.\frac{\partial q}{\partial t}\right|_\beta=-\beta v_g,
$$

which follows from material conservation of $$q+\beta y$$. QG transforms apply this term directly in physical QGPV space. Wave-bearing transforms apply it only to the balanced `A0` coefficients; their internal-wave frequencies and structures continue to use a constant Coriolis parameter.

```matlab
wvt.addForcing(WVBetaPlanePVAdvection(wvt));
```

## Diffusing displacement vertically

`WVVerticalDiffusivity` applies $$\mathcal{S}_\eta=\kappa_z\partial_{zz}\eta$$ to the represented displacement field. For variable stratification, `shouldForceMeanDensityAnomaly=true` also includes the horizontally uniform source $$-\kappa_z\partial_z\ln N^2$$, which projects onto the mean-density-anomaly component rather than the wave modes. For stratified QG, which has no mean-density-anomaly component, the corresponding QGPV tendency is $$\mathcal{S}_q=-f\partial_z\mathcal{S}_\eta$$ and the option has no effect.

## Creating your own forcing

Custom forcing subclasses derive from `WVForcing`, declare one or more `WVForcingType` stages, and override the method corresponding to each declared stage. Physical-space forcing modifies velocity and displacement tendencies before projection. Spectral forcing modifies $$(F_+,F_-,F_0)$$ after projection. Spectral-amplitude forcing modifies the tendency of constrained coefficients and restores their exact `Ap`, `Am`, or `A0` values after an integration step.

For example, horizontal and vertical spectral damping can be expressed as

$$
    \begin{align}
        \partial_t A_\pm^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_\pm^{k\ell j} - \nu_z \lambda_j^{-2} A_\pm^{k\ell j} \\
        \partial_t A_0^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_0^{k\ell j} - \nu_z \lambda_j^{-2} A_0^{k\ell j}
    \end{align}
$$

and implemented by overriding `addSpectralForcing`. Hydrostatic and nonhydrostatic physical forcing instead override `addHydrostaticSpatialForcing` or `addNonhydrostaticSpatialForcing`. QG forcing uses the potential-vorticity variants of the spatial, spectral, or amplitude interfaces.

The transform validates that a forcing stage is compatible with its dynamics, applies stages in physical–spectral–amplitude order, and uses `priority` to order forcing objects within one stage. See [`WVForcing`](/classes/forcing/wvforcing/) and the [`forcingType` stage table](/classes/forcing/wvforcing/forcingtype.html) before implementing a subclass.
