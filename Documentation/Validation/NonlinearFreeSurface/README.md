# Nonlinear free-surface implementation evidence

This directory records the active nonlinear free-surface Boussinesq increment (#449/#450, with the relevant #448 guard). The implementation is not yet qualified nonlinear dynamics. The baseline is WVM `81987767` and InternalModes `2.0.0-beta.4`. The existing linear and small-amplitude QG scope remains distinct.

## Initial source and surface-constraint audit

The model reconstructs SSH from its reference-time coefficient vector using a row operator $C_\zeta(t)$. Analytical modal phases already satisfy the linear surface kinematics for frozen amplitudes. Therefore an additional amplitude tendency $B$ with no surface mass source must satisfy $C_\zeta(t)B=0$ if the retained model is to impose the pointwise kinematic condition. Velocity divergence alone does not establish this condition.

The [source probe](../../../tools/nonlinear-study/runFreeSurfaceKinematicProbe.m) applies generic smooth displacement and momentum sources to the existing projector. The [results](source-kinematic-probe.csv) include two stratifications and 4, 8, or 16 wave modes, with three APV modes, two MDA modes, and both active endpoints. Rates in this file are maxima of the real spatial harmonic. For example, a constant-stratification displacement source with peak rate $10^{-5}$ m/s produces an SSH rate of $8.47\times10^{-10}$ m/s with four wave modes, reducing to $7.09\times10^{-12}$ m/s with sixteen. The transverse-acceleration result is not monotonic under wave-only refinement with a fixed APV band. These observations concern cancellation between independently truncated families; they do not prescribe a new count policy.

The original exploratory relative divergence denominator consisted of reconstructed derivative terms which can all vanish for these sources. It was replaced with a source-based scale, and the corrected CSV records absolute divergence too. Source-scaled divergence is at roundoff while generic-source SSH rates remain measurable. No nearly-zero derivative denominator is used as evidence for a continuity failure.

For the existing source projector $P$ and a reference-gradient pressure source $G\phi=(ik\phi,i\ell\phi,D_\xi\phi,0)$, $C_\zeta P G\phi=0$ algebraically. Balanced source rows see zero curl and no displacement source. Wave pressure-gradient pairings are identical for the two frequency signs, while their SSH polarizations have opposite signs. The probe confirms negligible SSH responses for pressure profiles with both zero and nonzero surface trace. Consequently ordinary pressure-gradient adjustment cannot repair $C_\zeta P R\ne0$ for an arbitrary truncated residual $R$.

## Constrained projection feasibility and limits

The [constrained study](../../../tools/nonlinear-study/runFreeSurfaceConstrainedProjectionStudy.m) constructs the full positive physical quadratic Gram matrix $H$, including balanced cross terms, and rows reconstructing SSH, surface interior displacement, and bottom displacement. It tests the minimum-$H$ correction to the existing projected source with either SSH alone or all three trace constraints.

All tested matrices have the expected constraint ranks one and three; the smallest normalized constraint singular value is 0.9178. With all three constraints enforced, Fourier-amplitude rate residuals are no larger than $3.77\times10^{-22}$ m/s for SSH, $1.11\times10^{-20}$ m/s for the surface anomaly, and $1.28\times10^{-21}$ m/s for the bottom anomaly. Already-admissible corrections are preserved within $9.43\times10^{-17}$. These are complex Fourier amplitudes, so they should not be equated directly with the real-space maxima in the first probe.

This feasibility result does not establish a physical closure. The correction changes source work, and SSH-only correction leaves endpoint-rate errors. Normalized differences between reconstructed quadratic energy rate and direct physical source work remain $1.94\times10^{-4}$ to $8.37\times10^{-3}$ after enforcing all three constraints. The [36-row CSV](constrained-source-projection-study.csv) records raw and corrected quantities with a noncancelling work scale. Its normalized mixed state varies with count, so it is not a fixed-state continuum-convergence study.

The coefficient constraint multiplier is not an ordinary pressure field. Production adoption requires a derived weak momentum/displacement formulation and an energy/work identity appropriate to the nonlinear available energy. The current quadratic Gram is useful for the diagnostic experiment but does not supply that nonlinear conservation law. No ad hoc SSH subtraction or energy repair has been adopted into model evolution.

## Reproduction

Configure the authoring WVM and pinned dependencies with `configureCIEnvironment`, add `tools/nonlinear-study` to the path, then run `runFreeSurfaceKinematicProbe(outputFolder)` and `runFreeSurfaceConstrainedProjectionStudy(outputFolder)`. The exact study settings and source-probe digest are in [provenance](projection-probe-provenance.json). Both studies are tiny-grid mathematical controls, not production benchmarks.

## Instantaneous mapped equations and pressure oracle

`WVInternal.freeSurfaceMappedTendency` evaluates the full unforced hatted equations given exact buoyancy and the complete diagnostic pressure. It includes pressure inside the horizontal acceleration that contributes to the vertical equation. It supplies neither a pressure solve nor modal evolution. Three independent controls check the physical material equations by differentiating the inverse map, pressure acceleration on a sloping surface, and the flat inertial/hydrostatic limit.

The [dense pressure oracle](../../../tools/nonlinear-study/solveFreeSurfacePressureReference.m) separately assembles $\nabla_\xi\cdot(M\nabla_\xi\pi)=\nabla_\xi\cdot F$, with bottom normal acceleration zero and prescribed surface pressure. Here $F$ is the pressure-free mapped acceleration and $\pi$ is pressure divided by reference density. The matrix $M$ includes the complete geometric pressure response. This authoring-only routine is limited to 1500 samples and is not a proposed production solver.

The oracle replaces the two endpoint rows with boundary conditions; it reports endpoint divergence separately from interior divergence. An analytic nonflat manufactured-pressure test also adds a known divergence-free acceleration, checking pressure recovery within $2\times10^{-11}$ m²/s² and the remaining acceleration within $2\times10^{-12}$ m/s². A second test compares its independently assembled pressure response with the mapped-RHS helper, checking interior continuity, bottom acceleration and the dynamic surface condition. A third freezes the metric at the reference geometry and independently recovers the resolved mixed-mode linear pressure and modal accelerations, with relative tolerances $2\times10^{-7}$ and $2\times10^{-6}$ respectively. These tests establish an instantaneous grid-level diagnostic. They do not establish the surface-kinematic compatibility of a projected modal tendency.

## Verification ledger

- QG `eta_i`: three new tests passed across constant/exponential profiles, all endpoint configurations, built-in/custom components and coefficient cache invalidation. Three selected existing QG reconstruction, nonlinear-advection and stored-construction tests passed.
- Shared component registration: QG and Boussinesq now register `eta_i` through the existing supported-variable filter, removing the QG override and Boussinesq special case. The QG displacement tests, selected Boussinesq operations/custom-component/cache tests and existing surface-component diagnostics passed after consolidation. Code Analyzer reported no findings in the changed registration source and test files.
- Unsupported v4 advection guard: three new tests and ten existing forcing/evolution cases passed, covering registry preservation, conversion, restoration and v4/QG controls.
- Physical-coordinate helper: three analytic tests passed, including physical streamfunction reconstruction, material reference-coordinate velocity, displacement identities, endpoints, flat-surface instantaneous motion and invalid geometry rejection. Code Analyzer reported no findings in the helper or test class.
- Full mapped tendency: three analytic tests passed; Code Analyzer reported no findings in the helper and test class.
- Dense pressure reference: manufactured, mapped-RHS and resolved linear-limit tests passed; Code Analyzer reported no findings in the oracle and test class. The initial short-domain linear fixture correctly failed the existing bottom-resolution guard at 33 vertical points; the mixed-family linear control uses the established 100 km by 100 km by 1 km domain, preserving the guard and its tolerance.
- Source audit: thirty generic-source controls generated the corrected source-scaled diagnostics.
- Constrained study: thirty-six rows generated; Code Analyzer and whitespace checks passed.
- Integrated API documentation: build and check passed with 2362 files, 4827 routes and zero generated drift. The added QG field shifts generated navigation ordering. A second build/check after removing the redundant registration override also passed; the pressure diagnostic adds no generated API source.
- These results do not establish a nonlinear pressure solve, nonlinear trajectories, nonlinear energy conservation, or nonlinear restart. Those remain active goal requirements.
