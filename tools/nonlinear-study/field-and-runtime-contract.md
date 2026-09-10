# Field and runtime contract for the nonlinear beta increment

This records the implementation target after the weak-solver and pressure-reference studies. Public activation and caller updates are still pending. The current class's provisional `reconstructFields` still returns hatted velocities; it must not be described as implementing the contract below until that batch is complete.

## Field meanings

Use the ordinary v4 physical-velocity idiom without making meanings conditional on registered forcing:

| Name | Meaning |
| --- | --- |
| `u`, `v`, `w` | Physical velocity on the moving mesh |
| `ssu`, `ssv` | Physical horizontal velocity at that mesh's surface |
| `u_hat`, `v_hat`, `w_hat` | Fixed-reference modal velocity variables |
| `eta` | Total material displacement |
| `eta_i` | `eta-(1+xi/D)*ssh`, the displacement of a parcel label relative to the fixed column |
| `ssh` | Surface height with the existing zero-mean gauge |
| `z` | Existing one-dimensional reference sample coordinate; no rename |
| `z_physical` | Three-dimensional moving physical height |
| `w_i` | Material reference-coordinate rate |
| `p_linear` | Pressure from the linear modal polarization, including the hydrostatic MDA mean |
| `p_full` | Instantaneous full collocation pressure diagnostic for the selected equations, with its residual qualification |
| `qgpv` | Existing linear reference-coordinate QGPV diagnostic; not the nonlinear material APV |

Remove provisional bare `p` rather than preserve an ambiguous alias. This is an intentional beta API change. Keep low-level `reconstructSpectralState` explicitly documented as reconstruction of hatted modal fields; it is also the internal linear-algebra primitive. Expose hatted sampled fields through `reconstructFields`' explicit names. The full pressure operation must not call a constraint multiplier pressure, and must distinguish collocation equation error from modal momentum projection error.

Rename the existing quadratic `physicalEnergy` inventory to `quadraticEnergy`, retaining its positive physical Gram and all cross terms. Add `nonlinearEnergy` for the physical-volume kinetic plus exact APE and full surface energy. There is no migration alias or change of which formula is returned based on forcing registration.

## Components and caches

For component `c`, map its hatted velocity using the **total** state:

$$
u_c=\hat u_c/\gamma,\qquad v_c=\hat v_c/\gamma,\qquad w_c=\hat w_c+s(u_c\zeta_x+v_c\zeta_y).
$$

These are additive contributions to the full physical velocity. They are not independent finite-amplitude solutions with their own surface geometry. `eta_i,c=eta_c-s*ssh_c` remains linear. A component contribution to `w_i` uses the same total Jacobian and its linear `hat(w)_c-s*hat(w)_c(surface)` numerator.

`z_physical`, `p_full`, and `nonlinearEnergy` are total-state quantities; do not invent nonlinear pressure or energy partitions. Register supported component fields through the existing flow-component and operation machinery. The mapped velocity annotations must depend on every coefficient family and on the linear clocks, even when the component mask itself contains only balanced modes. Hatted balanced fields may retain their existing clock-independent caching. Test warmed balanced-component caches while the total surface changes through wave phases, at nonzero `t` and `t0`.

## Projection and source boundaries

`projectFields` should accept ordinary physical `u/v/w`, total displacement and SSH. Invert the physical map using the supplied SSH before applying the existing resolved adiabatic modal projection. Preserve modal counts, signed projection duals and existing quality diagnostics; clearly label any diagnostic norm evaluated on the hatted reference fields. A reconstructed physical state must round-trip through that inverse map without redefining the basis.

The continuous `projectSources` method remains an explicitly **linear** source projection, with hatted equation-source meanings documented at its boundary. It is not the full nonlinear physical-forcing closure. In a nonlinear run, supported physical volume acceleration and displacement sources must enter the stage equation and its coupled closure before projection; source work must use their physical meaning. Independent surface mass sources remain outside this increment.

## Runtime and persistence

Use the existing `WVModel` six-family `coefficientTendency` path and explicit nonlinear registration, retaining the supported linear default. Reconstruct a stage once and reuse geometry, thermodynamics, derivative handles, and reference factors. Existing `diffX`/`diffY` already differentiate on the full Fourier sample grid and should be reused where their backend contract matches the nonlinear work; nonlinear products must not first be reduced to retained modal coefficients.

Persist the scientific field/dynamics convention and canonical families with unchanged per-kappa counts. Rebuild derived factors and thermodynamic primitives on restoration without solving EVPs. Update output names and example callers directly. Before activating ordinary physical velocities, audit tracers and particles: physical `w` is not a reference-coordinate trajectory rate. Either adapt a bounded observer contract to `w_i` and the correct horizontal rates, or reject the unsupported nonlinear combination explicitly.

Completion requires the public operations, inverse projection, caches, forcing dispatch, observations and native restart tests to agree with these definitions. This document alone does not implement them.
