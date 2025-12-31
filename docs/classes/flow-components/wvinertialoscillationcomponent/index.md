---
layout: default
title: WVInertialOscillationComponent
has_children: false
has_toc: false
mathjax: true
parent: Flow components
grand_parent: Class documentation
nav_order: 6
---

#  WVInertialOscillationComponent

Inertial oscillation solution group


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVInertialOscillationComponent < WVFlowComponent</code></pre></div></div>



## Topics
+ Analytical solutions
  + [`inertialOscillationSolution`](/classes/flow-components/wvinertialoscillationcomponent/inertialoscillationsolution.html) return a real-valued analytical solution of the internal gravity wave mode
  + [`maskOfConjugateModesForCoefficientMatrix`](/classes/flow-components/wvinertialoscillationcomponent/maskofconjugatemodesforcoefficientmatrix.html) returns a mask indicating where the redundant (conjugate )solutions live in the requested coefficient matrix.
  + [`maskOfPrimaryModesForCoefficientMatrix`](/classes/flow-components/wvinertialoscillationcomponent/maskofprimarymodesforcoefficientmatrix.html) returns a mask indicating where the primary (non-conjugate) solutions live in the requested coefficient matrix.
  + [`solutionForModeAtIndex`](/classes/flow-components/wvinertialoscillationcomponent/solutionformodeatindex.html) return the analytical solution at this index
+ Index Gymnastics
  + [`isValidConjugateModeNumber`](/classes/flow-components/wvinertialoscillationcomponent/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
  + [`isValidModeNumber`](/classes/flow-components/wvinertialoscillationcomponent/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
  + [`isValidPrimaryModeNumber`](/classes/flow-components/wvinertialoscillationcomponent/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
+ Masks
  + [`maskOfModesForCoefficientMatrix`](/classes/flow-components/wvinertialoscillationcomponent/maskofmodesforcoefficientmatrix.html) returns a mask indicating where solutions live in the requested coefficient matrix.
+ Properties
  + [`nModes`](/classes/flow-components/wvinertialoscillationcomponent/nmodes.html) return the number of unique modes of this type
+ Quadratic quantities
  + [`totalEnergyFactorForCoefficientMatrix`](/classes/flow-components/wvinertialoscillationcomponent/totalenergyfactorforcoefficientmatrix.html) returns the total energy multiplier for the coefficient matrix.
+ Other
  + [`WVInertialOscillationComponent`](/classes/flow-components/wvinertialoscillationcomponent/wvinertialoscillationcomponent.html) Inertial oscillation solution group
  + [`degreesOfFreedomPerMode`](/classes/flow-components/wvinertialoscillationcomponent/degreesoffreedompermode.html) 
  + [`inertialOscillationSpatialTransformCoefficients`](/classes/flow-components/wvinertialoscillationcomponent/inertialoscillationspatialtransformcoefficients.html) 


---