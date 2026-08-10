---
layout: default
title: forcingType
parent: WVForcing
grand_parent: Forcing
nav_order: 9
mathjax: true
---

#  forcingType

Evaluation stages implemented by this forcing.


---

## Type
+ Class: `WVForcingType`

## Discussion

Each `WVForcingType` value declares the method or methods that a
subclass implements:

| Type | Evaluation method |
| --- | --- |
| `HydrostaticSpatial` | `addHydrostaticSpatialForcing` |
| `NonhydrostaticSpatial` | `addNonhydrostaticSpatialForcing` |
| `PVSpatial` | `addPotentialVorticitySpatialForcing` |
| `Spectral` | `addSpectralForcing` |
| `PVSpectral` | `addPotentialVorticitySpectralForcing` |
| `SpectralAmplitude` | `setSpectralForcing` and `setSpectralAmplitude` |
| `PVSpectralAmplitude` | `setPotentialVorticitySpectralForcing` and `setPotentialVorticitySpectralAmplitude` |

Spectral-amplitude forcing first modifies the coefficient tendency
with the corresponding `*SpectralForcing` method. After an
integration step, the corresponding `*SpectralAmplitude` method
restores the constrained coefficient values exactly.
