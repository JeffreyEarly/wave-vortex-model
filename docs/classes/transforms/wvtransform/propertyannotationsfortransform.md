---
layout: default
title: propertyAnnotationsForTransform
parent: WVTransform
grand_parent: Classes
nav_order: 80
mathjax: true
---

#  propertyAnnotationsForTransform

return array of CAPropertyAnnotations for the WVTransform


---

## Declaration
```matlab
 [propertyAnnotations,A0Prop,ApProp,AmProp] = WVTransform.propertyAnnotationsForTransform()
```
## Returns
+ `propertyAnnotations`  array of CAPropertyAnnotation instances
+ `A0Prop`  CANumericProperty instance for A0
+ `ApProp`  CANumericProperty instance for Ap
+ `AmProp`  CANumericProperty instance for Am

## Discussion

  This function returns annotations for all properties defined
  by the WVTransform. It selectively returns annotations for
  the wave-vortex coefficients, as not all subclass will handle
  these coefficients in the same way.
 
            
