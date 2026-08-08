---
layout: default
title: WVEulerianFields
has_children: false
has_toc: false
mathjax: true
parent: Observing systems
grand_parent: Class documentation
nav_order: 2
---

#  WVEulerianFields

Select transform fields for model output


---

## Overview

WVEulerianFields records named WVTransform fields, separating values
written once at initialization from fields written at every output time.


## Topics
+ Create an observing system
  + [`WVEulerianFields`](/classes/observing-systems/wveulerianfields/wveulerianfields.html) create a new observing system
+ Configure sampled variables
  + [`addNetCDFOutputVariables`](/classes/observing-systems/wveulerianfields/addnetcdfoutputvariables.html) Add variables to list of variables to be written to the NetCDF variable during the model run.
  + [`removeNetCDFOutputVariables`](/classes/observing-systems/wveulerianfields/removenetcdfoutputvariables.html) Remove variables from the list of variables to be written to the NetCDF variable during the model run.
  + [`setNetCDFOutputVariables`](/classes/observing-systems/wveulerianfields/setnetcdfoutputvariables.html) Set list of variables to be written to the NetCDF variable during the model run.
+ Inspect observed state
  + [`fieldNames`](/classes/observing-systems/wveulerianfields/fieldnames.html) eulerian field names


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Observing-system internals
  + [`classRequiredPropertyNames`](/classes/observing-systems/wveulerianfields/classrequiredpropertynames.html)
  + [`nOutputVariables`](/classes/observing-systems/wveulerianfields/noutputvariables.html)
  + [`nTimeSeriesVariables`](/classes/observing-systems/wveulerianfields/ntimeseriesvariables.html)
  + [`observingSystemWithResolutionOfTransform`](/classes/observing-systems/wveulerianfields/observingsystemwithresolutionoftransform.html) create a new WVObservingSystem with a new resolution
  + [`timeSeriesVariables`](/classes/observing-systems/wveulerianfields/timeseriesvariables.html)
+ Observer integration
  + [`initialConditionOnlyVariables`](/classes/observing-systems/wveulerianfields/initialconditiononlyvariables.html)
+ Observing-system persistence
  + [`netCDFOutputVariables`](/classes/observing-systems/wveulerianfields/netcdfoutputvariables.html)
  + [`updateNetCDFVariableCategorization`](/classes/observing-systems/wveulerianfields/updatenetcdfvariablecategorization.html)


---