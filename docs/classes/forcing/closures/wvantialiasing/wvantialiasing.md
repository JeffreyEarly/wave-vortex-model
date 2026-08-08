---
layout: default
title: WVAntialiasing
parent: WVAntialiasing
grand_parent: Classes
nav_order: 2
mathjax: true
---

#  WVAntialiasing

initialize the WVAntialiasing


---

## Declaration
```matlab
 nlFlux = WVNonlinearFlux(wvt,options)
```
## Parameters
+ `wvt`  a WVTransform instance
+ `Nj`  (optional) number of retained vertical modes. Modes with `j >= Nj` are set to zero. Defaults to `floor(2*wvt.Nj/3)`.

## Returns
+ `self`  a WVAntialiasing instance

## Discussion

        
