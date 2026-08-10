---
layout: default
title: summarizeModeEnergy
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 265
mathjax: true
---

#  summarizeModeEnergy

List the most energetic modes


---

## Declaration
```matlab
 summarizeModeEnergy(options)
```
## Parameters
+ `options.n`  number of modes to list; default `10`

## Discussion

At the moment the +/- waves are simply added together for each mode.
It would be better if they were separate.
