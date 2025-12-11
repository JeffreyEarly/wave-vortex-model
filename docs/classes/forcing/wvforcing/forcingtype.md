---
layout: default
title: forcingType
parent: WVForcing
grand_parent: Classes
nav_order: 10
mathjax: true
---

#  forcingType

Array of supported forcing types


---

## Discussion

  If the class supports a given forcing type, that indicates that
  the class implements a particular methods. The correspondence is
  as follows:
  WVForcingType                 Method
  -------------                 ------
  HydrostaticSpatial            addHydrostaticSpatialForcing
  NonhydrostaticSpatial         addNonhydrostaticSpatialForcing
  PVSpatial                     addPotentialVorticitySpatialForcing
  Spectral                      addSpectralForcing
  PVSpectral                    addPotentialVorticitySpectralForcing
  SpectralAmplitude             setSpectralForcing / setSpectralAmplitude
  PVSpectralAmplitude           setPotentialVorticitySpectralForcing / setPotentialVorticitySpectralAmplitude
 
  
