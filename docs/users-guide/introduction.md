---
layout: default
title: Introduction
parent: User guide
mathjax: true
nav_order: 1
---

# Introduction

WaveVortexModel separates the representation of a fluid state from its time evolution. The `WV` prefix means wave–vortex and provides a common namespace for the package's classes.

## `WVTransform`: represent and diagnose a state

A [`WVTransform`](/classes/transforms/wvtransform/) represents the state of a rotating fluid at a reference time. Wave-bearing transforms store that state in the wave–vortex coefficients `Ap`, `Am`, and `A0`; quasigeostrophic transforms use `A0`. The transform reconstructs physical variables such as velocity, density, pressure, and potential vorticity when they are requested.

Transforms also provide the forward projection from physical fields to coefficients, spectral differentiation and integration, interpolation at periodic off-grid positions, energetics, spectra, and flow-component diagnostics. Choose the transform family to match the desired stratification and dynamical approximation.

## `WVModel`: evolve and observe a state

A [`WVModel`](/classes/wvmodel/) advances a `WVTransform` in time. Analytical linear evolution is useful for evaluating a prescribed superposition of modes. Fixed-step and adaptive integration evolve active coefficient and observing-system dynamics.

The model coordinates forcing and closures, Lagrangian particles, tracers, moorings, Eulerian fields, and wave–vortex coefficients. Output files and output groups allow these observing systems to be sampled on different schedules and restored for a later restart.

## A typical workflow

1. Construct the appropriate `WVTransform`.
2. Initialize it from physical fields, individual modes, a spectrum, or a saved file.
3. Inspect reconstructed fields and diagnostics.
4. If integrating nonlinear dynamics, configure forcing and a closure.
5. Construct a `WVModel`, add observing systems or output, and integrate.

Continue with [Using `WVTransform`](/users-guide/using-the-wvtransform.html) for concrete construction and initialization examples.
