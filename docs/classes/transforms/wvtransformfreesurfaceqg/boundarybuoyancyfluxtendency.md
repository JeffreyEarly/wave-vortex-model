---
layout: default
title: boundaryBuoyancyFluxTendency
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 57
mathjax: true
---

#  boundaryBuoyancyFluxTendency

Project prescribed inward buoyancy fluxes onto the canonical families.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `options.surfaceBuoyancyFlux`  inward surface buoyancy flux on the horizontal grid in $$\mathrm{m^{2}\,s^{-3}}$$
+ `options.bottomBuoyancyFlux`  inward bottom buoyancy flux on the horizontal grid in $$\mathrm{m^{2}\,s^{-3}}$$

## Returns
+ `tendency`  structure with Ag_q, Ag_0, and Amda tendencies

## Discussion

At each nonzero horizontal wavenumber the load uses the positive energy
matrix and the total-displacement traces of the balanced modes.
$$E\dot a=-\boldsymbol{\eta}(0)^*\widehat Q_0-\boldsymbol{\eta}(-D)^*\widehat Q_d.$$
The mean load uses buoyancy variance and supplies the prescribed
column buoyancy input through the MDA inventory coordinate. A nonzero
inward flux requires an active endpoint.
