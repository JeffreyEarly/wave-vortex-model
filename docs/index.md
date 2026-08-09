---
layout: default
title: Home
nav_order: 1
description: "Decompose and model rotating stratified flow with wave-vortex modes"
permalink: /
---

# WaveVortexModel

WaveVortexModel represents rotating, stratified Boussinesq flow on an energetically orthogonal basis of internal waves, inertial oscillations, geostrophic motions, and mean-density anomalies.

Use a [`WVTransform`](/classes/transforms/wvtransform/) to decompose a fluid state, reconstruct physical fields, and calculate diagnostics. Use [`WVModel`](/classes/wvmodel/) to integrate the state while advecting particles and tracers, sampling observing systems, and writing restartable NetCDF output.

## Quick start

Create a small constant-stratification transform, initialize one internal wave, inspect its velocity field, and advance the state with analytical linear dynamics:

```matlab
wvt = WVTransformConstantStratification( ...
    [40e3 40e3 1000], [16 16 9], N0=5.2e-3, latitude=45);

[omega,k,l] = wvt.initWithWaveModes( ...
    kMode=1, lMode=0, j=1, phi=0, u=0.05, sign=1);
[u,v,w] = wvt.variableWithName('u','v','w');

model = WVModel(wvt,shouldUseLinearDynamics=true);
model.integrateToTime(600,shouldShowIntegrationDiagnostics=false);
```

The transform stores the decomposed state in `Ap`, `Am`, and `A0`. Variables such as velocity, density, pressure, energy, and potential vorticity are reconstructed from those coefficients when requested.

## Start here

| Goal | Documentation |
| --- | --- |
| Install the package | [Installation](/installation) |
| Choose and construct a transform | [Using `WVTransform`](/users-guide/using-the-wvtransform.html) |
| Understand the main objects | [Introduction](/users-guide/introduction.html) |
| Add forcing and closures | [Adding forcing](/users-guide/adding-forcing.html) |
| Write output and restart a model | [Reading and writing files](/users-guide/reading-and-writing-to-file.html) |
| Check a capability or limitation | [Capabilities and limitations](/users-guide/supported-features.html) |
| Browse classes and methods | [API reference](/classes/) |

## Scientific basis

The generalized decomposition is described by [Early, Lelong, and Sundermeyer (2021)](https://doi.org/10.1017/jfm.2020.995). The available-potential-vorticity formulation is described by [Early et al. (2024)](https://doi.org/10.48550/arXiv.2403.20269). See [Acknowledgements and citations](/acknowledgements) for software citation information and BibTeX downloads.
