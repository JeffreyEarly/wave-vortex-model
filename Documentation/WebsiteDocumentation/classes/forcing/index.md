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

| Class | Purpose | Supported transforms | Principal controls |
| --- | --- | --- | --- |
| [`WVNonlinearAdvection`](/classes/forcing/wvnonlinearadvection/) | Nonlinear momentum, displacement, and QGPV advection | All transform families | None; added by default |
| [`WVBottomFrictionLinear`](/classes/forcing/wvbottomfrictionlinear/) | Linear drag at the bottom boundary | All transform families | Drag rate `r` |
| [`WVBottomFrictionQuadratic`](/classes/forcing/wvbottomfrictionquadratic/) | Quadratic drag at the bottom boundary | All transform families | Drag coefficient `Cd` |
| [`WVFixedAmplitudeForcing`](/classes/forcing/wvfixedamplitudeforcing/) | Hold selected `Ap`, `Am`, or `A0` coefficients fixed | All transform families | Registry `name`, selected indices, and target coefficients |
| [`WVBetaPlanePVAdvection`](/classes/forcing/wvbetaplanepvadvection/) | Add beta-plane QGPV advection | All transform families through their compatible PV or spectral stage | No user parameter |
| [`WVPseudoTopographicWaveGeneration`](/classes/forcing/wvpseudotopographicwavegeneration/) | Generate internal waves from prescribed barotropic flow over topography | Wave-bearing three-dimensional transforms | Topography, velocity amplitude, tidal frequency, ramp, and spectral bounds |
