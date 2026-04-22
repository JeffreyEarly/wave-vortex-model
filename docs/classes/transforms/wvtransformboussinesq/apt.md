---
layout: default
title: Apt
parent: WVTransformBoussinesq
grand_parent: Classes
nav_order: 10
mathjax: true
---

#  Apt

positive wave coefficients at reference time t


---

## Description
Complex valued property with dimensions $$(j,kl)$$ and units of $$m/s$$.

## Discussion

These are the *time dependent* coefficients of the internal gravity wave and inertial oscillation portion of the flow, denoted  $$A_+ e^{i \omega t} $$ in [Early, et al. (2021)](https://doi.org/10.1017/jfm.2020.995).

Unlike `Ap`, these coefficients do not have their phases wound to time $$t_0$$ (`t0`), and **do** change for linear dynamics.

