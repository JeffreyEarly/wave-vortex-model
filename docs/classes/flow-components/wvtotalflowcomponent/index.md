---
layout: default
title: WVTotalFlowComponent
has_children: false
has_toc: false
mathjax: true
parent: Flow components
grand_parent: Class documentation
nav_order: 3
---

#  WVTotalFlowComponent

Orthogonal solution group


---

## Overview

ch degree-of-freedom in the model is associated with an analytical
lution to the equations of motion. This class groups together
lutions of a particular type and provides a mapping between their
alytical solutions and their numerical representation.

rhaps the most complicate part of the numerical implementation is
e indexing---finding where each solution is represented
merically. In general, a solution will have some properties, e.g.,
(kMode,lMode,jMode,phi,A,omegasign)
ich will have a primary and conjugate part, each of which might be
 two different matrices.




## Topics
+ Initialization
  + [`WVTotalFlowComponent`](/classes/flow-components/wvtotalflowcomponent/wvtotalflowcomponent.html) create a new orthogonal solution group
+ Properties
  + [`nModes`](/classes/flow-components/wvtotalflowcomponent/nmodes.html) return the number of unique modes of this type
+ Masks
  + [`maskOfConjugateModesForCoefficientMatrix`](/classes/flow-components/wvtotalflowcomponent/maskofconjugatemodesforcoefficientmatrix.html) returns a mask indicating where the redundant (conjugate )solutions live in the requested coefficient matrix.
  + [`maskOfModesForCoefficientMatrix`](/classes/flow-components/wvtotalflowcomponent/maskofmodesforcoefficientmatrix.html) returns a mask indicating where solutions live in the requested coefficient matrix.
  + [`maskOfPrimaryModesForCoefficientMatrix`](/classes/flow-components/wvtotalflowcomponent/maskofprimarymodesforcoefficientmatrix.html) returns a mask indicating where the primary (non-conjugate) solutions live in the requested coefficient matrix.
+ Quadratic quantities
  + [`totalEnergyFactorForCoefficientMatrix`](/classes/flow-components/wvtotalflowcomponent/totalenergyfactorforcoefficientmatrix.html) returns the total energy multiplier for the coefficient matrix.
+ Analytical solutions
  + [`solutionForModeAtIndex`](/classes/flow-components/wvtotalflowcomponent/solutionformodeatindex.html) Return analytical solutions from the complete primary-flow basis.
+ Index Gymnastics
  + [`isValidConjugateModeNumber`](/classes/flow-components/wvtotalflowcomponent/isvalidconjugatemodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
  + [`isValidModeNumber`](/classes/flow-components/wvtotalflowcomponent/isvalidmodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
  + [`isValidPrimaryModeNumber`](/classes/flow-components/wvtotalflowcomponent/isvalidprimarymodenumber.html) returns a boolean indicating whether (k,l,j) is a valid mode number
+ Other
  + [`degreesOfFreedomPerMode`](/classes/flow-components/wvtotalflowcomponent/degreesoffreedompermode.html)


---