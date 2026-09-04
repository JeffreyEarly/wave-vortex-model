---
layout: default
title: boundaryBuoyancyFluxTendency
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 58
mathjax: true
---

#  boundaryBuoyancyFluxTendency

Project prescribed inward buoyancy fluxes onto the canonical families.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `options.surfaceBuoyancyFlux`  inward surface buoyancy flux on the horizontal grid
+ `options.bottomBuoyancyFlux`  inward bottom buoyancy flux on the horizontal grid

## Returns
+ `tendency`  structure with Ag_q, Ag_0, and Amda tendencies

## Discussion

Each boundary load has displacement tendency -Q/(w*N2) at its endpoint.
Projection retains the interior APV response, residual endpoint response,
and horizontally uniform MDA source. A nonzero load requires an active
endpoint. These projections are independent of homogeneous diffusion.
