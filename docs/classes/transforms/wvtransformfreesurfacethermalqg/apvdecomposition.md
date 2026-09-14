---
layout: default
title: apvDecomposition
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 46
mathjax: true
---

#  apvDecomposition

Diagnose a complete thermal state with an independent APV and zero-APV basis.


---

## Parameters
+ `apv`  compatible WVTransformFreeSurfaceQG diagnostic transform
+ `options.state`  Ath/Amda structure; defaults to the current state
+ `options.tendency`  optional row of Ath/Amda directional tendencies
+ `options.time`  physical time recorded with the result, in seconds
+ `options.quadratureCount`  physical Gauss count, at least both stored grids and thermal count
+ `options.fieldNames`  requested physical fields for the second output

## Returns
+ `diagnosis`  coefficients, physical inventories, spectra, residuals and directional rates
+ `reconstruction`  selected total, APV, zero-APV, mean and residual physical fields

## Discussion

Project physical QGPV through the diagnostic F-channel Galerkin operator,
then subtract its endpoint response before finding zero-APV coefficients.
Physical accounting retains APV, zero-APV, the original thermal horizontal
mean, and the unresolved field. Neither transform's state or clock changes.
The diagnostic band is independent of any registered damping closure.

For physical quadrature weights W and sampled APV F modes, the projection
is $$a_q=(F^*WF)^{-1}F^*Wq$$, evaluated by weighted QR. The two endpoint
coefficients are $$a_0=-(g/f)k_h^2(\theta-E_k a_q)$$, where theta is the
interior-displacement anomaly and E_k is the APV endpoint response.
Both coefficient families have units $$s^{-1}$$. Their row counts are the
diagnostic APV count and two endpoints; columns follow the diagnostic
transform's nonzero Fourier order recorded in metadata.kNonzero/lNonzero.

Inventories use horizontally averaged depth integrals, with all physical
cross terms. Modal power is twice the squared coefficient magnitude in
s^-2; it is not a diagonal physical-energy spectrum. Radial spectra are bin
sums of nonzero Fourier contributions; mean inventories remain separate.
Residuals include absolute RMS, reference RMS and their ratio. A zero
reference gives NaN for the ratio. energyNorm uses sqrt(physical energy).

Each inventory has total, apv, zeroAPV, residual and mean self terms, and
apvZeroAPV, apvResidual and zeroAPVResidual cross terms. Their sum, excluding
total itself, recovers total. Energies have units $$m^{3}/s^{2}$$, potential
enstrophy $$m/s^{2}$$, and endpoint half second moments $$m^{2}$$. Physical
spectra use source Fourier order (metadata.accountingKNonzero and
accountingLNonzero); radialSpectrum contains bin sums and kRadial.

A row of canonical tendencies gives instantaneous coefficient and inventory
rates. It does not supply time-integrated process budgets. The caller owns
the process ordering and evaluates any forcing at the appropriate clock.
directional.residualRateNorms contains positive norms of the rate fields;
directional.inventories contains signed instantaneous work or variance rates.

With one output no physical volumes are allocated. The optional second
output reconstructs only fieldNames: volumes on the common physical Gauss
grid, SSH as Nx-by-Ny, and endpoints as Nx-by-Ny-by-2, surface then bottom.
Coordinates are reconstruction.x/y/z. Supported fields are psi, u, v, eta,
eta_i, buoyancy, qgpv, ssh and endpointAnomalies; the last two are defaults.
Cached quadrature and maps depend on immutable scientific arrays and the
diagnostic object, not on coefficients, time, forcing or damping rates.
Changing solved-basis physics requires new scientific transforms. A warmed
cache rejects changed gravity or rotation parameters. The diagnostic band,
signed endpoint weights and stored sampling may differ from the source.
Requested counts are not retained by existing transforms: metadata reports
their absence explicitly. Retain the constructor settings and saved arrays
with the analysis to preserve complete construction provenance.

```matlab
d = thermal.apvDecomposition(apv,quadratureCount=513);
[d,fields] = thermal.apvDecomposition(apv,fieldNames=["ssh","endpointAnomalies"]);
```
