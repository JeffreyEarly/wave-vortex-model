---
layout: default
title: WVVariableAnnotation
has_children: false
has_toc: false
mathjax: true
parent: Operations & annotations
grand_parent: Class documentation
nav_order: 2
---

#  WVVariableAnnotation

Describe a variable computed from a WVTransform.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVVariableAnnotation < WVAnnotation</code></pre></div></div>

## Overview

In addition to adding a name, description and detailed description of
a given variable, you also specify its dimensions, units, and whether
or whether it has an imaginary part. These annotations are used for
online documentation and for writing to NetCDF files.

Setting the two properties `isVariableWithLinearTimeStep` and
`isVariableWithNonlinearTimeStep` are important for determining
how the variable is cached, and when it is saved to a NetCDF file.

A matching Markdown sidecar named for the variable may provide the
longer mathematical or scientific description. `CAPropertyAnnotation`
locates that sidecar when detailed documentation is requested, and the
website builder merges the canonical sidecar into each generated class
reference that exposes the variable. This keeps equations and tables out
of constructor calls without disconnecting them from the annotation.




## Topics
+ Create operations and annotations
  + [`WVVariableAnnotation`](/classes/operations-and-annotations/wvvariableannotation/wvvariableannotation.html) create a new instance of WVVariableAnnotation
+ Inspect dependencies and outputs
  + [`isDependentOnApAmA0`](/classes/operations-and-annotations/wvvariableannotation/isdependentonapama0.html) boolean indicating whether the variable depends on Ap, Am, or A0
  + [`isVariableWithLinearTimeStep`](/classes/operations-and-annotations/wvvariableannotation/isvariablewithlineartimestep.html) boolean indicating whether the variable changes value with a linear time step
  + [`isVariableWithNonlinearTimeStep`](/classes/operations-and-annotations/wvvariableannotation/isvariablewithnonlineartimestep.html) boolean indicating whether the variable changes value with a non-linear time step


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Operation internals
  + [`modelOp`](/classes/operations-and-annotations/wvvariableannotation/modelop.html) WVOperation responsible for computing this variable


---