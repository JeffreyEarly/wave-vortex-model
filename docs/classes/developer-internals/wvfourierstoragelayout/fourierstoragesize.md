---
layout: default
title: fourierStorageSize
parent: WVFourierStorageLayout
grand_parent: Developer internals
nav_order: 9
mathjax: true
---

#  fourierStorageSize

Natural two-dimensional Fourier storage shape.

> Developer documentation: this item describes internal implementation details.


---

## Discussion
Full-complex, half-x, and half-y layouts have shapes [Nx,Ny],
[floor(Nx/2)+1,Ny], and [Nx,floor(Ny/2)+1], respectively.
