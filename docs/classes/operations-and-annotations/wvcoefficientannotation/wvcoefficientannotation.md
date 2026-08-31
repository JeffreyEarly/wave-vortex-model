---
layout: default
title: WVCoefficientAnnotation
parent: WVCoefficientAnnotation
grand_parent: Operations & annotations
nav_order: 1
mathjax: true
---

#  WVCoefficientAnnotation

Create a canonical coefficient-family annotation.


---

## Declaration
```matlab
 annotation = WVCoefficientAnnotation(name,dimensions,units,description,options)
```
## Parameters
+ `name`  coefficient property and tendency-field name
+ `dimensions`  ordered logical dimensions
+ `units`  canonical state units
+ `description`  short scientific description
+ `options.auxiliaryCoordinates`  associated coordinate names
+ `options.canonicalBasis`  public scientific basis
+ `options.persistenceRole`  persistence role; default `canonicalState`
+ `options.emptyFamilyPolicy`  `persist` or `omit`
+ `options.isComplex`  whether values may be complex

## Returns
+ `annotation`  coefficient-family annotation

## Discussion
