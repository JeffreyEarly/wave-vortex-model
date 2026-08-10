---
layout: default
title: NA0
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 22
mathjax: true
---

#  NA0

matrix component that multiplies $$A_0$$ to compute $$\tilde{\eta}$$.

> Developer documentation: this item describes internal implementation details.


---

## Description
Real valued property with dimensions $$(j,kl)$$ and no units.

## Discussion
These reconstruction coefficients map $$A_0$$ onto the density-displacement state variable. In the historical notation of [Early et al. (2021)](https://doi.org/10.1017/jfm.2020.995), they are the row 3, column 3 entries of $$S$$ for the primary internal-gravity-wave and geostrophic solutions in equation C4.

For $$k^2+l^2>0, j>0$$ this is written as,

$$
\textrm{NAm} \equiv 1
$$

in the manuscript. In code this is computed with,

```matlab
NA0 = ones(size(Kh));
```

There are no $$k^2+l^2>0, j=0$$ wave solutions for a rigid lid,

```matlab
NA0(:,:,1) = 0;
```

The inertial solutions occupy the $$k^2+l^2=0$$ portion of the matrix,

```matlab
NA0(1,1,:) = 0;
```
