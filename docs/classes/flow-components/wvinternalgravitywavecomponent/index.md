---
layout: default
title: WVInternalGravityWaveComponent
has_children: false
has_toc: false
mathjax: true
parent: Flow components
grand_parent: Class documentation
nav_order: 5
---

#  WVInternalGravityWaveComponent

Geostrophic solution group


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVInternalGravityWaveComponent < WVPrimaryFlowComponent</code></pre></div></div>

## Overview




## Topics
+ Create a flow component
  + [`WVInternalGravityWaveComponent`](/classes/flow-components/wvinternalgravitywavecomponent/wvinternalgravitywavecomponent.html)
+ Inspect a flow component
  + [`degreesOfFreedomPerMode`](/classes/flow-components/wvinternalgravitywavecomponent/degreesoffreedompermode.html)
  + [`nModes`](/classes/flow-components/wvinternalgravitywavecomponent/nmodes.html) return the number of unique modes of this type
+ Work with component modes
  + [`internalGravityWaveSolution`](/classes/flow-components/wvinternalgravitywavecomponent/internalgravitywavesolution.html) return a real-valued analytical solution of the internal gravity wave mode
  + [`normalizeWaveModeProperties`](/classes/flow-components/wvinternalgravitywavecomponent/normalizewavemodeproperties.html) returns properties of a internal gravity wave solutions relative to the primary mode number
  + [`solutionForModeAtIndex`](/classes/flow-components/wvinternalgravitywavecomponent/solutionformodeatindex.html) return the analytical solution at this index
+ Inspect component modes
  + Masks and validity
    + [`isValidConjugateModeNumber`](/classes/flow-components/wvinternalgravitywavecomponent/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
    + [`isValidModeNumber`](/classes/flow-components/wvinternalgravitywavecomponent/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
    + [`isValidPrimaryModeNumber`](/classes/flow-components/wvinternalgravitywavecomponent/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
    + [`maskOfConjugateModesForCoefficientMatrix`](/classes/flow-components/wvinternalgravitywavecomponent/maskofconjugatemodesforcoefficientmatrix.html) returns a mask indicating where the redundant (conjugate )solutions live in the requested coefficient matrix.
    + [`maskOfModesForCoefficientMatrix`](/classes/flow-components/wvinternalgravitywavecomponent/maskofmodesforcoefficientmatrix.html) returns a mask indicating where solutions live in the requested coefficient matrix.
    + [`maskOfPrimaryModesForCoefficientMatrix`](/classes/flow-components/wvinternalgravitywavecomponent/maskofprimarymodesforcoefficientmatrix.html) returns a mask indicating where the primary (non-conjugate) solutions live in the requested coefficient matrix.
+ Compute component energy
  + [`totalEnergyFactorForCoefficientMatrix`](/classes/flow-components/wvinternalgravitywavecomponent/totalenergyfactorforcoefficientmatrix.html) returns the total energy multiplier for the coefficient matrix.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Flow-component internals
  + [`internalGravityWaveSpatialTransformCoefficients`](/classes/flow-components/wvinternalgravitywavecomponent/internalgravitywavespatialtransformcoefficients.html)
  + [`internalGravityWaveSpectralTransformCoefficients`](/classes/flow-components/wvinternalgravitywavecomponent/internalgravitywavespectraltransformcoefficients.html)
  + [`summarizeModeAtIndex`](/classes/flow-components/wvinternalgravitywavecomponent/summarizemodeatindex.html)


---