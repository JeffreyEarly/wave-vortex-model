---
layout: default
title: Wavenumbers, modes, and indices
parent: User guide
mathjax: true
nav_order: 16
---

# Wavenumbers, modes, and indices

WaveVortexModel distinguishes physical wavenumbers, integer mode numbers, and array indices. Keeping those concepts separate is important when initializing modes or mapping between physical, DFT, and wave–vortex representations.

## Definitions

A **wavenumber** is a [spatial frequency](https://en.wikipedia.org/wiki/Wavenumber) with units of radians per meter. Every `WVTransform` has horizontal wavenumbers $$k$$ and $$l$$, and the constant-stratification transform also has vertical wavenumber $$m$$.

A **mode number** is a dimensionless integer label. `kMode`, `lMode`, and `j` identify a spectral solution independently of its storage location. The word *mode* may also refer to the corresponding geostrophic, wave, inertial, or mean-density-anomaly solution.

An **index** is a storage location in a MATLAB array. MATLAB provides [subscript, linear, and logical indexing](https://www.mathworks.com/company/technical-articles/matrix-indexing-in-matlab.html). Use the transform and flow-component mapping methods instead of assuming a particular internal ordering.

## More about modes

Each degree of freedom in the wave–vortex representation corresponds to a linear solution of the governing equations. A unique set of mode numbers, either `(kMode,lMode)` or `(kMode,lMode,j)`, identifies that solution. Two aspects of this identification are important:
1. each set of mode numbers identifies a unique solution, and
2. the choice of mode number for each solution is a matter of convention.

The unique labels stored by the transform are *primary* mode numbers. A physically equivalent Fourier representation may use a *conjugate* mode number, which maps back to the primary solution with the appropriate conjugation. The transform geometries provide:

- `bool = isValidPrimaryModeNumber(self,kMode,lMode,jMode)`
- `bool = isValidConjugateModeNumber(self,kMode,lMode,jMode)`
- `bool = isValidModeNumber(self,kMode,lMode,jMode)`

`isValidPrimaryModeNumber` identifies a unique stored solution. `isValidConjugateModeNumber` identifies a valid equivalent label that is not primary. `isValidModeNumber` accepts either form.

As a simple analogy, consider the periodic harmonic solution $$u = A \sin(n\pi x/L)$$. One convention could label $$1 \leq n \leq 7$$ as primary, while the equivalent negative labels $$-7 \leq n \leq -1$$ are conjugate. Both label the same physical solution set, but their amplitudes must be mapped consistently.

For doubly periodic geometry, the primary half-plane depends on the geometry's conjugate dimension. The mapping APIs hide that storage convention from ordinary initialization and analysis code.

WaveVortexModel's modes are solutions to linearized geophysical equations rather than the simple harmonic example. `WVPrimaryFlowComponent` subclasses classify the geostrophic, internal-wave, inertial, and mean-density-anomaly solutions and provide the same primary/conjugate validation methods for their own mode sets.
