---
layout: default
title: initWithGaussianEddy
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 108
mathjax: true
---

#  initWithGaussianEddy

Initialize a balanced, vertically shifted Gaussian eddy.


---

## Declaration
```matlab
 initWithGaussianEddy(options)
```
## Parameters
+ `options.maximumSpeed`  signed isolated-eddy velocity scale $$U$$ in meters per second
+ `options.horizontalRadius`  Gaussian horizontal radius $$L_e$$ in meters
+ `options.verticalScale`  Gaussian vertical scale $$H_e$$ in meters
+ `options.zCenter`  Gaussian vertical center $$z_c$$ in meters; default `0`
+ `options.center`  horizontal center `[xCenter yCenter]` in meters; default domain center

## Discussion

The raw streamfunction is

$$
\psi_{\mathrm{raw}}(x,y,z)
= U\frac{L_e}{\sqrt{2}}e^{1/2}P(x,y)
\exp\left[-\frac{(z-z_c)^2}{2H_e^2}\right],
$$

where `maximumSpeed`, `horizontalRadius`, `verticalScale`, and `zCenter`
are $$U$$, $$L_e$$, $$H_e$$, and $$z_c$$. `P` is the periodic Gaussian
centered at `center`. The amplitude gives maximum horizontal speed $$U$$
for an isolated Gaussian at its vertical center. `zCenter` may lie above
or below the modeled interval; choosing $$z_c\ne0$$ exposes a nonzero
surface displacement and buoyancy anomaly.

The initializer constructs

$$
\eta=-\frac{f}{N^2}\partial_z\psi_{\mathrm{raw}},
\qquad
q=\nabla_h^2\psi_{\mathrm{raw}}+
\partial_z\left(\frac{f^2}{N^2}
\partial_z\psi_{\mathrm{raw}}\right),
$$

and the active surface and bottom anomalies
$$b_0=\eta(0)-(f/g)\psi_{\mathrm{raw}}(0)$$ and
$$b_d=\eta(-D)$$. Nonzero horizontal wavenumbers are projected into
`Ag_q` followed by the residual `Ag_0`. The raw Gaussian's discrete
horizontal-mean displacement is projected independently into `Amda`.
Initialization replaces all three canonical coefficient families.

```matlab
wvt.initWithGaussianEddy(maximumSpeed=0.1,horizontalRadius=80e3, ...
    verticalScale=300,zCenter=100,center=[wvt.Lx/2 wvt.Ly/2]);
```
