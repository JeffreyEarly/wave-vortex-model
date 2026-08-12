---
layout: default
title: modelSpectrum
parent: WVNarrowBandGeostrophicForcing
grand_parent: Forcing
nav_order: 13
mathjax: true
---

#  modelSpectrum

Configured radial geostrophic energy-spectrum function.


---

## Type
+ Class: `function_handle`
+ Size: `(1,1)`

## Discussion

The returned handle accepts radial wavenumber in radians per meter
and returns spectral density in $$\mathrm{m^{3}\,s^{-2}}$$. It is
reconstructed from persisted scalar configuration and is not
itself written to NetCDF.
