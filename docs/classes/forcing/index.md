---
layout: default
title: Forcing
parent: Class documentation
mathjax: true
nav_order: 10
has_children: true
permalink: /classes/forcing
---

# Forcing

Forcing objects add physical-space tendencies, spectral tendencies, or direct coefficient constraints to a `WVTransform`. Register them with `wvt.addForcing(...)`; see [Adding forcing](/users-guide/adding-forcing.html) for the model equations and extension interface.

All forcing classes derive from [`WVForcing`](/classes/forcing/wvforcing/). New transforms contain nonlinear advection by default; other forcing and [closure](/classes/forcing/closures/) objects are added explicitly.

| Class | Purpose |
| --- | --- |
| [`WVNonlinearAdvection`](/classes/forcing/wvnonlinearadvection/) | Nonlinear momentum, displacement, and QGPV advection |
| [`WVBottomFrictionLinear`](/classes/forcing/wvbottomfrictionlinear/) | Linear drag at the bottom boundary |
| [`WVBottomFrictionQuadratic`](/classes/forcing/wvbottomfrictionquadratic/) | Quadratic drag at the bottom boundary |
| [`WVFixedAmplitudeForcing`](/classes/forcing/wvfixedamplitudeforcing/) | Hold selected `Ap`, `Am`, or `A0` coefficients fixed |
| [`WVNarrowBandGeostrophicForcing`](/classes/forcing/wvnarrowbandgeostrophicforcing/) | Initialize and hold a radial band of geostrophic `A0` coefficients |
| [`WVBetaPlanePVAdvection`](/classes/forcing/wvbetaplanepvadvection/) | Add the $$-\beta v_g$$ tendency to balanced QGPV |
| [`WVSeasonalSurfaceBuoyancyFlux`](/classes/forcing/wvseasonalsurfacebuoyancyflux/) | Apply a sinusoidal surface buoyancy flux to free-surface QG |
| [`WVPseudoTopographicWaveGeneration`](/classes/forcing/wvpseudotopographicwavegeneration/) | Project prescribed bottom velocity onto internal-wave modes |
