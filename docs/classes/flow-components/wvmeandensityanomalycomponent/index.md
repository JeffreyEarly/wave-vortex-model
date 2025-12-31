---
layout: default
title: WVMeanDensityAnomalyComponent
has_children: false
has_toc: false
mathjax: true
parent: Flow components
grand_parent: Class documentation
nav_order: 7
---

#  WVMeanDensityAnomalyComponent

Inertial oscillation solution group


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVInertialOscillationComponent < WVFlowComponent</code></pre></div></div>



## Topics
+ Index Gymnastics
  + [`isValidConjugateModeNumber`](/classes/flow-components/wvmeandensityanomalycomponent/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
  + [`isValidModeNumber`](/classes/flow-components/wvmeandensityanomalycomponent/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
  + [`isValidPrimaryModeNumber`](/classes/flow-components/wvmeandensityanomalycomponent/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
+ Masks
  + [`maskOfConjugateModesForCoefficientMatrix`](/classes/flow-components/wvmeandensityanomalycomponent/maskofconjugatemodesforcoefficientmatrix.html) returns a mask indicating where the redundant (conjugate )solutions live in the requested coefficient matrix.
  + [`maskOfModesForCoefficientMatrix`](/classes/flow-components/wvmeandensityanomalycomponent/maskofmodesforcoefficientmatrix.html) returns a mask indicating where solutions live in the requested coefficient matrix.
  + [`maskOfPrimaryModesForCoefficientMatrix`](/classes/flow-components/wvmeandensityanomalycomponent/maskofprimarymodesforcoefficientmatrix.html) returns a mask indicating where the primary (non-conjugate) solutions live in the requested coefficient matrix.
+ Analytical solutions
  + [`meanDensityAnomalySolution`](/classes/flow-components/wvmeandensityanomalycomponent/meandensityanomalysolution.html) return a real-valued analytical solution of the mean density anomaly mode
  + [`solutionForModeAtIndex`](/classes/flow-components/wvmeandensityanomalycomponent/solutionformodeatindex.html) return the analytical solution at this index
+ Properties
  + [`nModes`](/classes/flow-components/wvmeandensityanomalycomponent/nmodes.html) return the number of unique modes of this type
+ Quadratic quantities
  + [`totalEnergyFactorForCoefficientMatrix`](/classes/flow-components/wvmeandensityanomalycomponent/totalenergyfactorforcoefficientmatrix.html) returns the total energy multiplier for the coefficient matrix.
+ Other
  + [`WVMeanDensityAnomalyComponent`](/classes/flow-components/wvmeandensityanomalycomponent/wvmeandensityanomalycomponent.html) Inertial oscillation solution group
  + [`degreesOfFreedomPerMode`](/classes/flow-components/wvmeandensityanomalycomponent/degreesoffreedompermode.html) 
  + [`meanDensityAnomalySpatialTransformCoefficients`](/classes/flow-components/wvmeandensityanomalycomponent/meandensityanomalyspatialtransformcoefficients.html) 
  + [`meanDensityAnomalySpectralTransformCoefficients`](/classes/flow-components/wvmeandensityanomalycomponent/meandensityanomalyspectraltransformcoefficients.html) 
  + [`multiplierForVariable`](/classes/flow-components/wvmeandensityanomalycomponent/multiplierforvariable.html) 
  + [`normalization`](/classes/flow-components/wvmeandensityanomalycomponent/normalization.html) 


---