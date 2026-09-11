# Internal mapped weak RHS assembly

> Historical evidence. This report describes the retired weak/pressure implementation or its comparison studies. The executable solvers have been removed; see the [direct runtime qualification](direct-runtime-qualification.md) for the current implementation. Historical source links refer to revision `7b9ccda7`.

`[covector,target,diagnostics] = WVInternal.freeSurfaceWeakRHS(wvt,hatted,metric,buoyancy,piSurface,derivative,boundary)` assembles an unforced weak coefficient covector and retained kinematic target. It does not solve for a coefficient tendency, choose a density reference, choose a surface-pressure approximation, or infer physical volume pressure from a constraint reaction. `piSurface` is pressure divided by reference density, in m$^2$/s$^2$. `buoyancy` is supplied physical acceleration. The caller owns the consistency of the frozen metric with the hatted state and its declared thermodynamic reference.

The helper calls `freeSurfaceMappedTendency` with zero volume pressure to obtain the complete pressure-free mapped momentum tendency $F$ and total-displacement tendency $d$. It then applies the reconstruction adjoint to the volume test fields $R F$ and $m_\eta d$, where $R=M^{-1}$ is the same inverse physical kinetic metric used by `freeSurfaceWeakMassAction`, and $m_\eta$ is the supplied `displacementWeight`. The resulting weak load is

$$
r = U^* Q R F + E^* Q m_\eta d - W_s^* V\pi_s + g C^* V\hat w_s.
$$

Here $Q$ and $V$ are the stored volume quadrature and horizontal-average surface pairings; $W_s$ evaluates hatted vertical velocity at the surface, and $C$ evaluates SSH. Because the reconstruction adjoint includes vertical weights, the helper places $-\pi_s/Q_{ss}$ in its top vertical-velocity test field and places $g\hat w_s$ in its SSH test field. This keeps the surface load independent of the top quadrature weight and includes the supplied pressure only through the weak surface term.

For endpoint targets, it differentiates the full mapped interior displacement $\eta_i=\eta-(1+\xi/D)\zeta$ on the volume grid and then extracts the endpoints. This gives surface $-u_H\cdot\nabla_H(\eta_s-\zeta)$ and bottom $-u_H\cdot\nabla_H\eta_b$, using $u_H=\hat u_H/\gamma$. The SSH target is $\hat w_s$. The supplied boundary context selects active endpoints and returns retained coordinates separately from `diagnostics.discardedBoundaryTargetRMS`; `diagnostics.boundaryTargetFields` retains the physical sampled target fields. The mapped tendency's derivative provider must retain its existing support for SSH horizontal derivatives, but endpoint-target differentiation itself does not pass two-dimensional endpoint arrays to that provider.

All assembly uses the stored sample grid. No global basis is formed in the helper, no continuous `projectSources` dual is used, and no de-aliasing or nonlinear pressure qualification is implied by this implementation.

## Verification ledger

`UnitTests/TestFreeSurfaceWeakRHS.m` uses a constant-stratification 4-by-4-by-65 transform with the existing study-local dense basis and energy helpers, on the identical stored samples. The nonflat seed retains the study's admissible mean endpoint offsets and adds a transverse wave to exercise both horizontal slope components. Its labels are checked on the existing dense checkpoints and remain strictly inside the declared reference domain.

The tests verify:

- The assembled covector agrees with the dense weak study's explicit physical-metric volume and surface pairings within $2\times10^{-12}$ relative tolerance. Substituting that covector into the dense constrained solve recovers `freeSurfaceWeakStudyHelpers.weakTendency` within the same tolerance.
- Physical endpoint targets, independently differentiated as two-dimensional traces in the test, agree with the helper's volume-derivative construction and retained projection. Discarded target RMS agrees and is nonzero for the fixture.
- An independently supplied surface-pressure increment has virtual work $-\langle\hat w_s\,\delta\pi_s\rangle$, checking the pressure sign and top-weight normalization without introducing a volume-pressure closure.
- At nonzero phase clocks, a centered directional linear limit containing both wave signs, balanced, inertial, and MDA coefficients agrees with their analytical linear coefficient derivatives acted on by the flat physical mass, within $3\times10^{-8}$ relative tolerance. The difference step is $10^{-4}$. This control explicitly supplies linear buoyancy to isolate the analytical derivative; it does not claim uniform pointwise small-amplitude scaling for a clipped physical-height reference.

Both focused tests passed after the transverse-wave and negative-frequency fixtures were included. Code Analyzer passed for the two new MATLAB files; whitespace and scope checks passed. No existing helper, test, runtime class, public activation, package manifest, released snapshot, or generated documentation was changed. The coupled solver and reference-dependent stage construction remain separate integration work.
