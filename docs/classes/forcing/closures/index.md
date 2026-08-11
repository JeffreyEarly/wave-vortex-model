---
layout: default
title: Closures
parent: Forcing
mathjax: true
nav_order: 1
has_children: true
permalink: /classes/forcing/closures
---

# Closures

Closures are `WVForcing` objects that remove variance near unresolved scales. Nonlinear integrations normally include a closure; adaptive damping is the usual starting point.

| Class | Purpose |
| --- | --- |
| [`WVAdaptiveDamping`](/classes/forcing/closures/wvadaptivedamping/) | Adapt spectral damping to the instantaneous flow and effective resolution |
| [`WVHorizontalDamping`](/classes/forcing/closures/wvhorizontaldamping/) | Apply horizontal Laplacian viscosity and diffusivity |
| [`WVVerticalDamping`](/classes/forcing/closures/wvverticaldamping/) | Apply vertical Laplacian viscosity and diffusivity |
| [`WVVerticalDiffusivity`](/classes/forcing/closures/wvverticaldiffusivity/) | Diffuse displacement vertically and apply its induced QGPV tendency |
| [`WVThermalDamping`](/classes/forcing/closures/wvthermaldamping/) | Apply the current QG thermal-damping formulation |
| [`WVAntialiasing`](/classes/forcing/closures/wvantialiasing/) | Apply antialias filtering explicitly for diagnostics |

Here *viscosity* $$\nu$$ acts on momentum, *diffusivity* $$\kappa$$ acts on the thermodynamic field, and *damping* is the broader term for small-scale variance removal. Transform-level antialiasing remains the efficient default; explicit `WVAntialiasing` is intended for diagnosing its effect.

See [Adding forcing](/users-guide/adding-forcing.html) for registration and integration guidance.
