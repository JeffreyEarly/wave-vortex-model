---
layout: default
title: barotropicVelocityAmplitude
parent: WVPseudoTopographicWaveGeneration
grand_parent: Forcing
nav_order: 2
mathjax: true
---

#  barotropicVelocityAmplitude

Complex barotropic velocity amplitude in meters per second.


---

## Type
+ Class: `double`
+ Size: `(2,1)`

## Description
Complex valued property with dimension $$barotropicVelocityComponent$$ and units of $$m s^{-1}$$.

## Discussion

The two entries are the zonal and meridional amplitudes in
$$\mathbf{U}_{\mathrm{bt}}=R(\tau)\operatorname{Re}
\{\widehat{\mathbf{U}}_{\mathrm{bt}}e^{-i\omega\tau}\}$$, where
$$\tau=t-\mathtt{startTime}$$.
