# From the weak diagnostic to the WVM runtime

This supplements the nonlinear goal plan. The dense weak-budget experiment is an oracle for equations and truncation errors; its global reconstruction matrices are not the intended runtime architecture. Production activation remains pending trajectory, forcing, quadrature and persistence qualification.

## Existing lifecycle

`WVModel` already advances a structure of canonical families through `coefficientTendency`. The six free-surface families and their persisted per-kappa wave prefixes remain the prognostic state. The existing three-array `nonlinearFlux` interface is a v4-shaped interface and must not be used to squeeze this six-family state into three arrays.

The free-surface Boussinesq implementation currently accumulates four registered volume sources in `coefficientTendency` and applies the continuous `projectSources` dual. Preserve that supported linear-source path. Nonlinear evolution must explicitly select the derived weak formulation and its supported source convention. Do not silently change the existing source projector into a physical-Gram inverse.

Retain `WVForcing`, the forcing registry, ordinary operations, cache invalidation, `WVModel` and annotated persistence. There is no requirement for another transform hierarchy or another prognostic class. Whether dispatch lives in the existing nonlinear-advection forcing or one focused forcing implementation is an integration choice after its registration and restoration contracts are checked.

## Reconstruction and its adjoint

Let $R(t)$ reconstruct hatted velocity, total displacement and SSH from the existing reference-time coefficients. The internal `WVInternal.freeSurfaceReconstructionAdjoint` returns the adjoint under horizontally averaged volume quadrature and surface pairing. It includes neither a modal Gram inverse nor intrinsic $N^2$ or $g$ weights. Its defining identity uses the real coefficient pairing

$$
\langle R(t)a,d\rangle_W=\sum_{\text{families}}\operatorname{Re}\sum\overline a\,R^*(t)d.
$$

Nonzero compact Fourier columns contribute a factor two, the inertial mean has its own real/imaginary velocity convention, and MDA coefficients are real. Inactive wave padding is excluded from mathematical degrees of freedom and remains zero in returned arrays. None of these adjoint outputs alone is a coefficient tendency.

At a fixed stage state, use reconstruction, pointwise physical metrics and this adjoint to apply the positive weak mass matrix. This avoids storing one global basis column per real coefficient. The reference-geometry mass has independent Fourier-column blocks and is a candidate preconditioner; its full physical Gram must retain balanced cross terms. Do not substitute the signed continuous source dual for those blocks.

Nonlinear geometry couples Fourier columns and complex coefficients to their conjugates. An iterative SPD solve therefore needs the independent **real** coefficient representation, or an explicitly real inner product appropriate to a real-linear operator. Passing the six complex arrays blindly to a solver assuming complex linearity is not justified. The real packing must omit inactive wave entries and keep MDA real.

Surface and endpoint constraint actions require only reconstructed traces. Their adjoints can use SSH test fields and endpoint displacement test fields with the appropriate quadrature normalization. Store independent retained constraint coordinates; oversampled grid traces are not independent constraints. Report the discarded boundary-product harmonics separately from the retained constraint residual.

## Exact linear phases

Let $L$ be the existing analytic coefficient phase generator: $+i\omega$ on positive waves, $-i\omega$ on negative waves, $if$ on inertial modes, and zero on APV, zero-APV and MDA. At the current phase time, $R'(t)a=R(t)La$.

If the coupled weak solve returns $v$ such that $R(t)v$ represents the total instantaneous hatted field derivative, the reference-time RHS is

$$
\dot a=v-La.
$$

In particular, the total-derivative constraint $C(t)v=\hat w_s$ becomes $C(t)\dot a=0$ after subtracting the linear phase contribution. Endpoint anomaly targets retain their nonlinear transport rates because their linear phase derivative vanishes. A supplied analytical linear RHS must give $v=La$ and zero interaction-picture tendency to numerical precision.

The diagnostic trajectory driver can equivalently work with instantaneous real coefficients and $a(t)=\exp(Lt)A(t)$. This is an oracle for phase handling, not a reason to replace WVM's stored per-family phase factors with a dense exponential in production.

## Stage fields and sources

Evaluate the stage state once, then share hatted fields, geometry, material coordinate velocity, exact buoyancy, physical metric and supported sources across mass/RHS/constraint actions. Pressure inside the horizontal acceleration must remain included in the full mapped pressure response. The dense pressure oracle checks an instantaneous grid equation; its output does not automatically qualify the pressure associated with an approximately projected trajectory.

Keep mathematical meanings independent of whether a forcing is registered. Current linear modal fields, physical velocities on the moving mesh, material coordinate velocity, linear modal pressure and the complete diagnostic pressure must be distinguished explicitly when exposing operations. Nonlinear physical component views, if provided, use the full state's geometry so their sum reconstructs the total physical velocity. Mapping every component through its own surface would fail additivity.

Quadrature resolution is separate from retained mode counts. Construction policy and nonlinear activation must not silently reselect modes or trim an existing state. The current adjoint uses the stored grid and quadrature; an overintegrated implementation must compose its interpolation and quadrature with the corresponding adjoint, not pair an overintegrated reconstruction with a different-grid inverse transform and call it an adjoint.

## Gates before activation

1. Verify the internal adjoint by physical-space duality, including variable counts, a zero-wave page, both active boundaries and nonzero reference/current times.
2. Compare matrix-free mass and constraint actions/solves against the dense oracle on the same samples and quadrature. Then distinguish grid refinement, retained-family refinement and retained horizontal bandwidth.
3. Qualify short interaction-picture trajectories against timestep refinement and the direct finite-amplitude energy/work budget. Check density-label admissibility at each stage; exact linear reduction, a small KKT residual and one conserved scalar are insufficient.
4. Resolve the pressure-reference/surface-energy choice explicitly, qualify the matching diagnostic pressure, and define supported physical source and observer combinations.
5. Integrate the qualified path into ordinary `coefficientTendency`, forcing contracts and operation caches. Persist scientific configuration and canonical families; rebuild derived solver state on restart without EVPs or mode reselection.

The current primitive and studies do not activate nonlinear `WVModel` evolution. Existing linear experiments and their defaults remain supported throughout this sequence.
