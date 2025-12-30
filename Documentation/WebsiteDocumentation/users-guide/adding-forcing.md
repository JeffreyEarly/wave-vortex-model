---
layout: default
title: Adding forcing
parent: Users guide
nav_order: 4
mathjax: true
---

#  Adding forcing

The `WVTransform` is the linear part of the equations of motion and thus forcing is required for more interesting dynamics.

## Quick start

By default, a `WVTransform` is initialized with exactly one forcing term: nonlinear advection. To see this, initialize a new transform, then `summarizeForcing` to list all right-hand-side terms,
```matlab
wvt = WVTransformHydrostatic([800e3, 800e3, 4000],[64, 64, 65], N2=@(z) (3*2*pi/3600)^2*exp(2*z/1300),latitude=30);
wvt.summarizeForcing

            Name             IsClosure
    _____________________    _________

    "nonlinear advection"     "false"
 ```

This indicates that the only forcing term is the nonlinear advection. If the goal is to time-step a model, we also require a closure scheme to remove small scale features. For a first pass, we recommend using the `WVAdaptiveDamping`. You add a right-hand-side forcing term with `addForcing`,

```matlab
wvt.addForcing(WVAdaptiveDamping(wvt));
wvt.summarizeForcing

            Name             IsClosure
    _____________________    _________

    "nonlinear advection"     "false"
    "adaptive damping"        "true"
 ```

With this, you could now time-step the `WVTransform` forwards in time with the model,
```matlab
model = WVModel(wvt);
model.integrateToTime(wvt.inertialPeriod);
```
and it would include both nonlinear advection and small scale adaptive damping.


## The equations of motion

The equations of motion solved by the non-hydrostatic model are
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
is the nonlinear advection.

Adding forcing to a transform simply adds an additional right-hand-side term, $\mathcal{S}$.
