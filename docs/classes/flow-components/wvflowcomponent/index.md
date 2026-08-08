---
layout: default
title: WVFlowComponent
has_children: false
has_toc: false
mathjax: true
parent: Flow components
grand_parent: Class documentation
nav_order: 1
---

#  WVFlowComponent

Describe one family of orthogonal wave-vortex solutions.


---

## Overview

Each degree-of-freedom in the model is associated with an analytical
solution to the equations of motion. This class groups together
solutions of a particular type and provides a mapping between their
analytical solutions and their numerical representation.

Component masks identify the coefficient locations occupied by the
family. This indexing is an important part of the abstraction: one
analytical mode, identified by horizontal mode numbers, vertical mode,
amplitude, and phase, may require a primary coefficient and a Hermitian
conjugate stored at different locations or even in different members of
`Ap`, `Am`, and `A0`.

Primary components provide that mapping between mode numbers,
`WVOrthogonalSolution` objects, and coefficient locations. They also
define the degrees of freedom carried by each mode. Diagnostic or total
components may combine those masks without introducing a new independent
solution family.




## Topics
+ Create a flow component
  + [`WVFlowComponent`](/classes/flow-components/wvflowcomponent/wvflowcomponent.html) create a new orthogonal solution group
+ Inspect a flow component
  + [`abbreviatedName`](/classes/flow-components/wvflowcomponent/abbreviatedname.html) abbreviated name
  + [`name`](/classes/flow-components/wvflowcomponent/name.html) of the flow feature
  + [`shortName`](/classes/flow-components/wvflowcomponent/shortname.html) name of the flow feature
  + [`wvt`](/classes/flow-components/wvflowcomponent/wvt.html) reference to the wave vortex transform
+ Inspect component modes
  + Masks and validity
    + [`maskA0`](/classes/flow-components/wvflowcomponent/maska0.html) returns a mask indicating where solutions live in the A0 matrix.
    + [`maskAm`](/classes/flow-components/wvflowcomponent/maskam.html) returns a mask indicating where solutions live in the Am matrix.
    + [`maskAp`](/classes/flow-components/wvflowcomponent/maskap.html) returns a mask indicating where solutions live in the Ap matrix.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Flow-component internals
  + [`contains`](/classes/flow-components/wvflowcomponent/contains.html)
  + [`hasPVComponent`](/classes/flow-components/wvflowcomponent/haspvcomponent.html)
  + [`hasWaveComponent`](/classes/flow-components/wvflowcomponent/haswavecomponent.html)
  + [`plus`](/classes/flow-components/wvflowcomponent/plus.html)
  + [`randomAmplitudes`](/classes/flow-components/wvflowcomponent/randomamplitudes.html) returns random amplitude for a valid flow state
  + [`randomAmplitudesWithSpectrum`](/classes/flow-components/wvflowcomponent/randomamplitudeswithspectrum.html) initialize with coefficients following a specified spectrum


---