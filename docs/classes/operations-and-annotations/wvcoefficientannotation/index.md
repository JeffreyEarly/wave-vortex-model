---
layout: default
title: WVCoefficientAnnotation
has_children: false
has_toc: false
mathjax: true
parent: Operations & annotations
grand_parent: Class documentation
nav_order: 3
---

#  WVCoefficientAnnotation

Describe one canonical coefficient family of a WVTransform.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVCoefficientAnnotation < WVVariableAnnotation</code></pre></div></div>

## Overview

Coefficient annotations are the ordered state contract shared by the
integrator and NetCDF persistence. In addition to the ordinary numeric
annotation, they identify auxiliary coordinates, the public basis, the
persistence role, and whether a physically empty family is omitted from
NetCDF storage.




## Topics
+ Inspect coefficient annotations
  + [`auxiliaryCoordinates`](/classes/operations-and-annotations/wvcoefficientannotation/auxiliarycoordinates.html) Auxiliary coordinate variable names associated with this family.
  + [`canonicalBasis`](/classes/operations-and-annotations/wvcoefficientannotation/canonicalbasis.html) Scientific basis exposed by the public coefficient property.
  + [`emptyFamilyPolicy`](/classes/operations-and-annotations/wvcoefficientannotation/emptyfamilypolicy.html) NetCDF treatment when the canonical family is physically empty.
  + [`isPhysicallyPresent`](/classes/operations-and-annotations/wvcoefficientannotation/isphysicallypresent.html) Return whether this family has a physical NetCDF variable.
  + [`numericDomain`](/classes/operations-and-annotations/wvcoefficientannotation/numericdomain.html) Numeric-domain description used for validation and inspection.
  + [`persistenceRole`](/classes/operations-and-annotations/wvcoefficientannotation/persistencerole.html) Persistence role of this family.
+ Create operations and annotations
  + [`WVCoefficientAnnotation`](/classes/operations-and-annotations/wvcoefficientannotation/wvcoefficientannotation.html) Create a canonical coefficient-family annotation.


---