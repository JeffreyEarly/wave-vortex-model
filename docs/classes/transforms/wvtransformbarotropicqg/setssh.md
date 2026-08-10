---
layout: default
title: setSSH
parent: WVTransformBarotropicQG
grand_parent: Transforms
nav_order: 138
mathjax: true
---

#  setSSH

Set a barotropic geostrophic state from sea-surface height.


---

## Declaration
```matlab
 setSSH(ssh,options)
```
## Parameters
+ `ssh`  function handle accepting horizontal coordinate arrays and returning height in meters
+ `options.shouldRemoveMeanPressure`  remove the horizontal mean before initialization; default `false`

## Discussion
Set a barotropic geostrophic state from sea-surface height.

`ssh` is a function handle evaluated on the horizontal grid. The transform converts height to geostrophic streamfunction using $$\psi=g\eta/f$$. Set `shouldRemoveMeanPressure=true` to remove the horizontal mean first; the default is `false`.

```matlab
wvt.setSSH(@(x,y)0.1*cos(2*pi*x/wvt.Lx));
```
