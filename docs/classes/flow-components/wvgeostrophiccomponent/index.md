---
layout: default
title: WVGeostrophicComponent
has_children: false
has_toc: false
mathjax: true
parent: Flow components
grand_parent: Class documentation
nav_order: 4
---

#  WVGeostrophicComponent

Geostrophic solution group


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVGeostrophicComponent < WVPrimaryFlowComponent</code></pre></div></div>

## Overview
FlowConstituentGroup WVGeostrophicFlowGroup
WVInternalGravityWaveFlowGroup
WVRigidLidFlowGroup
OrthogonalSolutionGroup



## Topics
+ Create a flow component
  + [`WVGeostrophicComponent`](/classes/flow-components/wvgeostrophiccomponent/wvgeostrophiccomponent.html)
+ Inspect a flow component
  + [`degreesOfFreedomPerMode`](/classes/flow-components/wvgeostrophiccomponent/degreesoffreedompermode.html)
  + [`nModes`](/classes/flow-components/wvgeostrophiccomponent/nmodes.html) return the number of unique modes of this type
+ Work with component modes
  + [`geostrophicSolution`](/classes/flow-components/wvgeostrophiccomponent/geostrophicsolution.html) return a real-valued analytical solution of the geostrophic mode
  + [`normalizeGeostrophicModeProperties`](/classes/flow-components/wvgeostrophiccomponent/normalizegeostrophicmodeproperties.html) returns properties of a geostrophic solution relative to the primary mode number
  + [`solutionForModeAtIndex`](/classes/flow-components/wvgeostrophiccomponent/solutionformodeatindex.html) return the analytical solution at this index
+ Inspect component modes
  + Masks and validity
    + [`isValidConjugateModeNumber`](/classes/flow-components/wvgeostrophiccomponent/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
    + [`isValidModeNumber`](/classes/flow-components/wvgeostrophiccomponent/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
    + [`isValidPrimaryModeNumber`](/classes/flow-components/wvgeostrophiccomponent/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
    + [`maskOfConjugateModesForCoefficientMatrix`](/classes/flow-components/wvgeostrophiccomponent/maskofconjugatemodesforcoefficientmatrix.html) returns a mask indicating where the redundant (conjugate )solutions live in the requested coefficient matrix.
    + [`maskOfModesForCoefficientMatrix`](/classes/flow-components/wvgeostrophiccomponent/maskofmodesforcoefficientmatrix.html) returns a mask indicating where solutions live in the requested coefficient matrix.
    + [`maskOfPrimaryModesForCoefficientMatrix`](/classes/flow-components/wvgeostrophiccomponent/maskofprimarymodesforcoefficientmatrix.html) returns a mask indicating where the primary (non-conjugate) solutions live in the requested coefficient matrix.
+ Compute component energy
  + [`totalEnergyFactorForCoefficientMatrix`](/classes/flow-components/wvgeostrophiccomponent/totalenergyfactorforcoefficientmatrix.html) returns the total energy multiplier for the coefficient matrix.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Flow-component internals
  + [`multiplierForVariable`](/classes/flow-components/wvgeostrophiccomponent/multiplierforvariable.html)
  + [`normalization`](/classes/flow-components/wvgeostrophiccomponent/normalization.html)


---