---
layout: default
title: summarizeDegreesOfFreedom
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 258
mathjax: true
---

#  summarizeDegreesOfFreedom

Summarize the spatial grid and active spectral degrees of freedom.


---

## Declaration
```matlab
 summarizeDegreesOfFreedom()
```
## Discussion

The summary lists each primary flow component in lexical `shortName`
order. Mode counts come from the component's active primary spectral
masks in the transform's current antialias configuration. Each subtotal
is the mode count multiplied by the component's degrees of freedom per
mode; the final line sums those subtotals. The method does not assert an
equivalence between spatial-grid values and active spectral degrees of
freedom.
