# Advection-form assessment (#483)

**Recommendation: retain the production divergence form.** The alternatives show no repeatable improvement in physical accuracy or runtime on the tested configurations. Keep the authoring candidates and controls for future qualification.

This authoring experiment compares four discretizations of the same free-surface displacement equations. Pressure, thermodynamics, modal projection, and the production dense vertical derivative remain fixed. The baseline is v5 `2ee008de824a9ff8ba0c943bf47098b20a14ca1c`; no production implementation is changed.

## Mathematics and discrete compatibility

Write the transport velocity as $V=(\hat u,\hat v,\hat w-\alpha b)$, with $\alpha=1+\xi/D$, $b=\hat w(0)$, $\gamma=1+\zeta/D$, and $c=\nabla_\xi\cdot V=-b/D$. The material transport is $M(a)=V\cdot\nabla_\xi a=\nabla_\xi\cdot(Va)-ca$. Horizontal momentum uses $\mathcal N_u=M(\hat u/\gamma)+c\hat u/\gamma$, and similarly for v. The other terms are

$$\mathcal N_w=\gamma^{-1}M(w)+(D+\xi)\left[\mathcal H\cdot\nabla_H\ln\gamma+\hat{\mathbf u}_H\cdot\nabla_H\left(\frac b{D\gamma}\right)\right],$$

$$\mathcal N_\eta=\gamma^{-1}\left[M(\hat\eta)-\alpha\hat{\mathbf u}_H\cdot\nabla_H\zeta\right].$$

Here $w=\hat w+(D+\xi)\hat{\mathbf u}_H\cdot\nabla_H\ln\gamma$. The horizontal tendency $\mathcal H$ includes the candidate horizontal advection, Coriolis acceleration, modal pressure gradient, and nonlinear pressure correction. Changing horizontal advection must also change its contribution inside vertical advection. All pressure/buoyancy corrections and signs are copied from the production source evaluator; coefficient tendencies project $-\mathcal N-\mathcal P$ with the existing phase conventions.

These identities are recorded in `literature/ape-apv-free-surface/main.tex`, Appendix C, labels `eq:projection-ready-flux-advection-identity`, `eq:projection-ready-vertical-advection-advective`, and `eq:projection-ready-displacement-advection-advective`.

For sampled derivative operators $D_j$, the four material operators are

$$M_D(a)=\sum_j D_j(V_j a)-ca,\qquad M_A(a)=\sum_j V_jD_j a,\qquad M_S(a)=\tfrac12(M_D(a)+M_A(a)).$$

The arithmetic average $M_S$ is not automatically compatible with the quadrature. Let $W$ be the reference vertical quadrature matrix and $B=\operatorname{diag}(-1,0,\ldots,0,1)$ the oriented endpoint matrix. Define $D_\xi^\dagger=W^{-1}(B-D_\xi^T W)$ and

$$M_C(a)=\tfrac12\left[\sum_jD_j(V_j a)+V_xD_xa+V_yD_ya+V_\xi D_\xi^\dagger a-ca\right].$$

Periodic Fourier differentiation is skew-adjoint under the horizontal uniform weights. With the same $W$ used in $D_\xi^\dagger$, direct matrix algebra gives

$$\langle a,M_C(a)\rangle_W=\tfrac12\langle V_\xi a^2\rangle_{\rm top-bottom}-\tfrac12\langle c,a^2\rangle_W.$$

The identity holds even for unresolved sampled fields. The transported vertical velocity vanishes at the top; any bottom residual is retained in the boundary term. For an isolated passive scalar, $\gamma_t=-c$ connects this identity to its Jacobian-weighted quadratic budget. It does **not** prove conservation of the complete projected physical energy or density moments: their nonlinear chain rules, geometry, thermodynamics, and modal projection add further requirements. The projected surface tendency can also retain a finite trace residual relative to b. No tendencies are repaired.

The compatible candidate uses a weighted transpose of the existing derivative matrix, prepared once per operator. It is a different split discretization, not a faster derivative backend. Its accuracy must be measured; exact scalar budget algebra does not establish consistency or endpoint accuracy. This construction follows the skew-adjoint principle discussed by [Tadmor (1984)](https://math.umd.edu/~tadmor/pub/PDEs/Tadmor%20Skew-adjoint%20form%20JMAA1984.pdf); the discrete identity above is derived and tested directly here.

## Protocol

[comparison-protocol.json](comparison-protocol.json) fixes the experiment before results are selected. Constant and exponential stratification, a linear-limit wave state, finite-amplitude waves, and mixed states with active boundaries are included. The domain is 100 km by 100 km by 1 km; all dependency, physical-parameter, amplitude, norm, and timestep conventions follow the completed [thermodynamic assessment](../thermodynamic-formulation-study/README.md).

The primary comparison uses 360 trajectories of 160 seconds, four forms, independent horizontal/vertical/mode refinement, and RK4 timesteps 20, 10, and 5 seconds. The common reference uses 24×24×129 samples and timestep 2.5 seconds; halved timestep and increased-mode controls must fall below one quarter of any claimed accuracy target. The declared absolute RMS velocity/density/SSH targets are $(10^{-3},10^{-3},10^{-2})$, $(10^{-4},10^{-4},10^{-3})$, and $(10^{-5},10^{-5},10^{-4})$ in m/s, kg/m³, and m. Initialization is included in errors. Reference agreement is empirical evidence, not a rigorous bound.

Separate instantaneous tests use independently reconstructed and projected mixed states at amplitudes $10^{-4}$, 0.1, and 0.4 and phase clocks 327 and 901 seconds. Fixed mode inventories isolate horizontal and vertical sampling effects; 48×48×129 and 32×32×257 checks resolve source-reference sensitivity. Sources are Fourier-resampled and interpolated in the analytic WKB coordinate for comparison. Coefficient errors compare common retained horizontal wavenumbers in each of the six families; omitted high horizontal modes are assessed through trajectory refinement instead.

Analytic scalar references deliberately stress Fourier aliasing, vertical oscillation, and boundary localization; the scalar is dimensionless and the horizontal velocity amplitude is 1 m/s. Full physical budgets integrate the analytic derivative of energy and density moments along each candidate RHS. They distinguish invariant defects from time-integration bookkeeping errors. Unforced external work is zero. Fixed padding/truncation is not asserted to exactly dealias rational geometry; antialias truncation is disabled and resolution is tested explicitly.

## Reproduction

With manifest-compatible dependencies and the WVM package on the MATLAB path:

```matlab
addpath('tools/advection-form-study','tools/thermodynamic-formulation-study', ...
    'tools/nonlinear-study','UnitTests/ReferenceImplementations')
runAdvectionManufacturedStudy
runAdvectionSourceStudy
runAdvectionTrajectories
runAdvectionBudgetControls
runAdvectionLongControls
countAdvectionDerivatives
runAdvectionTimings % run after other simulation processes finish
plotAdvectionStudy
```

Run `UnitTests/TestAdvectionForms.m` for independent analytic, endpoint-budget, and production-equivalence checks. Results are CSV files under `results/`. Timing qualification must run without concurrent simulations.

## Operation accounting

The [instrumented source ledger](results/derivative-counts.csv) counts calls over an H×Z volume separately from calls over an H-element surface. Reconstruction and modal projection are shared and excluded from this kernel ledger.

| Form | Volume x derivatives | Volume y derivatives | Volume vertical applications | Surface x/y derivatives |
| --- | ---: | ---: | ---: | ---: |
| Divergence | 5 | 5 | 5 | 2 / 2 |
| Advective | 5 | 5 | 5 | 2 / 2 |
| Arithmetic split | 9 | 9 | 9 | 2 / 2 |
| Compatible split | 9 | 9 | 5 ordinary + 4 weighted adjoint | 2 / 2 |

Each horizontal directional derivative uses forward/inverse 1D FFT batches. Each vertical application uses the production dense matrix or its precomputed weighted adjoint. All variants have the same asymptotic order in this MATLAB schedule: dense modal work, O(HZ log H) horizontal work, O(HZ²) vertical work, and O(HZP) thermodynamics. FFT-backed vertical calculus would replace the ordinary dense derivative cost by O(HZ log Z); it is not part of this comparison. Removing continuum cancellations changes products and constants, not the leading order. Split forms add work in this schedule; no minimum-operation claim is made.

## Physical trajectory accuracy

All 360 primary trajectories completed with valid parcel labels. Every form meets all three declared targets on the small 8×8×33 grid at dt=20 s, including the reference-error margin. Across the six profile/state cases, maximum small-grid errors are approximately 3.9e-7 m/s in velocity, 8.7e-7 kg/m³ in density, and 2.2e-7 m in SSH. Differences between forms are negligible at these error scales. The largest independent reference check is below 0.001 of the strictest target, comfortably inside the prescribed quarter-target requirement.

The higher-grid and higher-mode runs establish that the common error is predominantly unrelated to this advection-form choice in these smooth states. Single-run trajectory times collected during concurrent studies are retained for reproducibility but are not used to claim performance differences; the isolated repeated timings decide that comparison.

## Analytic and budget controls

The [manufactured scalar results](results/manufactured.csv) show why neither continuum equivalence nor a scalar invariant decides the algorithm. At Nx=8, Nz=17, advective transport has about 2.1e-8 RMS error in the oscillatory case, compared with 1.4e-4 for divergence and 7.1e-5 for the splits. This is a deliberately aliased sampled-source comparison, not evidence that a coarsely projected model recovers missing modes. At Nx=32, Nz=33, the ordinary forms approach roundoff, while the quadrature-adjoint form has about 1.0e-8 error; at Nz=65 it still has about 2.4e-9 error. Its exact weighted scalar identity comes with much slower vertical convergence for this quadrature/operator pairing.

The random-array endpoint test verifies the compatible identity without assuming resolved products or zero endpoint flux. The analytic source test independently differentiates the complete continuum expressions, including the horizontal tendency inside vertical advection. The production-equivalence test checks every coefficient family at two modal phase clocks.

The [64 physical budget controls](results/budgets.csv) integrate energy and two centered density-moment rates along each RHS, on two grids/mode inventories, two profiles, two finite-amplitude states, and two timesteps. Maximum energy bookkeeping error is about 2.8e-14, while the physical invariant defects remain nonzero. For the small exponential mixed case at dt=5 s, the 40-second energy change is about 3.0e-9 for every form. Scalar compatibility does not remove this full-model defect. Absolute bookkeeping errors for density moments are also recorded; cancellation against their larger inventories limits those diagnostics.

## Source versus projection refinement

The source comparison retains absolute errors and reference RMS values per field and per coefficient family, rather than combining quantities with different units. In the constant-profile, amplitude-0.4 control on 16×16×65 samples, the ordinary forms' maximum displacement-source errors are about 2.1e-16 m/s; the compatible form's error is about 3.9e-11 m/s. Its loss of source accuracy is consistent with the independent scalar test.

The full projected RHS also contains common pressure and buoyancy corrections. Some wave-family reference differences remain around 0.1% on this grid even when the ordinary forms' gridded sources agree tightly. All forms share this error. The [family ledger](results/families.csv) records it explicitly; the same-grid tendency comparison isolates differences caused by advection. These data do not establish universal qualification of the full nonpolynomial RHS or its projection, which remains #450's scope.

The 32 longer trajectories cover 2,000 seconds for the exponential wave and mixed states. All four forms retain maximum small-grid density errors of about 6.3e-6 kg/m³, with essentially identical energy changes. Their independent reference checks are reported separately from the short-run checks. No long-time turbulence or universal stability claim follows from these bounded controls.

## Verification ledger

The three focused test methods pass: independent analytic continuum sources, the discrete scalar budget with nonzero endpoint flux, and production agreement across all coefficient families and two phase clocks. The source-comparison harness was corrected to match common integer Fourier-mode indices across unequal grids, then the complete source study was rerun. This correction changes comparison bookkeeping, not any numerical RHS.

`docs:check` validates 2,362 files and 4,827 routes and reports only the two established generated-document differences: `docs/classes/developer-internals/wvdensitydiffusionintegrator/index.md` and `docs/version-history.md`. Those files are preserved. Code Analyzer reports no findings in the study and test files, including the subsequently updated comparison/plot/timing files. The timing pass was repeated after adding an untimed complete trajectory per variant to exclude first-call compilation. CSV finiteness, JSON/Python syntax, local links, whitespace, and repository scope pass. The final figure was rendered and visually inspected. No production, API, manifest, released snapshot, or website source changes are part of this assessment.


The report's [accuracy and cost figure](results/accuracy-and-cost.png) contrasts the independent scalar convergence test with complete-RHS medians. It does not imply that the analytic scalar error is a model trajectory error. Full five-trial timing samples and ranges are retained in [RHS timings](results/rhs-timings.csv) and [trajectory timings](results/trajectory-timings.csv). The [matched-target ledger](results/matched-targets.csv) verifies all 72 profile/state/target/form combinations; each meets its target on the small grid. Run `python3 tools/advection-form-study/summarizeAdvectionStudy.py` to reproduce that ledger.

## Measured runtime

Five trials follow three RHS warmups and a complete untimed small-grid trajectory per variant. The table gives median complete-RHS time relative to production. The final column compares the two prototypes directly. Trial samples and ranges are retained in the CSV files.

| Profile | Grid, wave modes | Divergence prototype | Advective | Split | Compatible | Advective / divergence prototype |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| constant | 8×8×33, 4 | 0.950 | 0.962 | 1.181 | 1.053 | 1.013 |
| constant | 16×16×65, 4 | 0.938 | 0.943 | 1.148 | 1.063 | 1.006 |
| constant | 16×16×65, 8 | 0.947 | 0.969 | 1.133 | 1.090 | 1.023 |
| constant | 24×24×129, 12 | 0.976 | 0.966 | 1.120 | 1.085 | 0.990 |
| exponential | 8×8×33, 4 | 0.971 | 0.966 | 1.153 | 1.019 | 0.995 |
| exponential | 16×16×65, 4 | 1.013 | 1.004 | 1.213 | 1.133 | 0.991 |
| exponential | 16×16×65, 8 | 1.006 | 1.002 | 1.198 | 1.146 | 0.996 |
| exponential | 24×24×129, 12 | 1.024 | 1.016 | 1.152 | 1.120 | 0.992 |

The 160-second mixed-state trajectories include physical diagnostics every 40 seconds. Their warmed medians are:

| Profile | Production | Divergence prototype | Advective | Split | Compatible |
| --- | ---: | ---: | ---: | ---: | ---: |
| constant | 97.7 ms | 94.9 ms | 99.4 ms | 114.7 ms | 95.2 ms |
| exponential | 93.6 ms | 90.3 ms | 90.1 ms | 106.2 ms | 96.7 ms |

The advective/divergence-prototype differences do not establish a repeatable useful gain. Comparisons with production alone would overstate a formula benefit because the divergence prototype shares much of the same timing difference. All these small-grid runs meet the same declared physical targets. Runtime is MATLAB R2026a Update 4 on MACA64; [runtime metadata](results/runtime.json) records the measured environment and source baseline.

## Adoption decision

Retain divergence for the production MATLAB implementation. Advective form is an equivalent continuum expression and can reduce error in deliberately under-resolved scalar tests, but the resolved projected model shows no meaningful physical-error or invariant advantage. Its derivative count is unchanged, and its timing relative to the equally prepared divergence prototype is effectively tied. Arithmetic splitting adds derivative work; the quadrature-adjoint split also sacrifices rapid source convergence for an exact scalar budget that does not conserve the full model.

The divergence prototype itself can differ in time from the production wrapper. Any gain shared by both divergence and advective prototypes is implementation scheduling/setup overhead, not evidence for changing advection; isolate that work under #484 before adopting it. The remaining shared projection sensitivity is relevant to #450. This assessment completes the requested comparison without selecting a new thermodynamic variable, changing modal pressure, switching derivative backends, or adding a release gate. No C++ performance or universal nonlinear-stability conclusion is claimed.
