# QG APV and active-boundary assessment

Issue [#426](https://github.com/JeffreyEarly/wave-vortex-model/issues/426) extends the optional authoring assessment to the implemented small-amplitude QG dynamics. It reuses the resolved adiabatic modes from `prepareSourceStudy`; no runtime class, constructor policy, coefficient count, checkpoint, dependency version, or packaged API changes.

## Physical operators

The free-surface manuscript `ape-apv-free-surface/main.tex`, equations `eq:free-surface-quasigeostrophy-qgpv-small-amplitude`, `eq:apv-geostrophic-eigenvalue`, `eq:apv-geostrophic-vertical-normalization`, and `eq:zero-apv-endpoint-response`, supplies the governing definitions. The endpoint transport follows the boundary-label equation `eq:boundary-label-density-endpoint-transport` in its small-amplitude QG limit. This assessment covers the implemented equations, not the manuscript's higher-order finite-surface corrections or nonlinear Boussinesq dynamics.

With streamfunction ψ, velocity is (−ψ_y, ψ_x), interior PV is q, and the two endpoint anomalies are b_s = η(0) − (f/g)ψ(0) and b_b = η(−D). The source equations are q_t = −J(ψ,q) and (b_e)_t = −J(ψ_e,b_e). For an ordered Fourier pair, the full Jacobian multiplier is k_1 l_2 − l_1 k_2. The two Cartesian terms are also measured separately, including exact structural zeros.

The implementation follows [WVNonlinearAdvection](../../Forcing/WVNonlinearAdvection.m), [projectQuasigeostrophicSpatialTendency](../../@WVTransformFreeSurfaceQG/projectQuasigeostrophicSpatialTendency.m), and [transformStateForward](../../@WVTransformFreeSurfaceQG/transformStateForward.m):

1. Project q_t with the actual sampled APV F dual. Its continuous reference is D⁻¹∫F_j q_t dz, with ∫F_i F_j dz/D = δ_ij. This channel has a positive volume pairing; a signed G projection is not substituted for it.
2. Compute each APV endpoint response E_e a_t. Here μ_j = κ² + f²/(g h_j) and E_ej = −(f/g) B_ej/μ_j, with B_sj = G_j(0) − F_j(0) and B_bj = G_j(−D).
3. Form the residual b_t − E a_t and obtain the zero-APV tendency −(g/f)κ²(b_t − E a_t). Surface and bottom remain independent physical coordinates. No scalar F/G Gram identity or ordered boundary prefix is introduced.

Input columns use streamfunction amplitudes for convenience; `qgStudyFields` explicitly records the conversion to the canonical APV and zero-APV coefficients. Canonical zero-APV endpoint observations are prescribed exactly. Their numerical endpoint identities are checked separately, preventing a roundoff residual at the opposite endpoint from becoming a fictitious advected anomaly.

## Separate error and qualification gates

APV sampling errors use the existing prescribed-dual projection and positive F coefficient norm, divided by the reference product's volume norm. Each endpoint source has its own absolute-value norm in physical anomaly-tendency units. The APV-induced endpoint residual error uses the Cauchy bound ‖E_e‖_* ‖q_t‖, where ‖E_e‖_*² = E_e M_F⁻¹ E_e*. This reports the error transmitted through the actual endpoint functional without dividing by a cancelled residual or mixing PV and displacement units. The direct boundary source and the APV compensation are reported separately; assembled states then test their combined effect.

Independent quadrature and EVP comparisons retain the mixed relative/absolute reference policy from #428. APV products reuse `qualifyProductReferences`. Endpoint observations use a sampled physical bound sup_z|ψ_a| |b_b,e| times the appropriate horizontal derivative multiplier. This bound remains meaningful when the velocity at the opposite boundary is tiny. Residual-functional reference budgets use the corresponding induced APV bound. Both reference allowances must be at most one percent of the requested product tolerance. Raw relative errors and absolute-qualification flags remain visible. A reference-qualified tiny product is not certified to its displayed relative error.

The fixed-boundary gate separately measures physical F and G derivatives, zero-APV balance, both endpoint identities, the coupled physical energy form, and the signed generalized energy form. The latter contains g_0 b_s² + g_d b_b². Differences are measured with the positive majorant containing |g_0| and |g_d|, never the possibly indefinite generalized energy itself. Every configured response is retained. An underresolved boundary cannot be hidden by reducing a wave count or silently discarding an endpoint. APV Gram and shared mode-convergence gates remain separate.

`assessQGAssembledTendency` constructs a deterministic resolved state and compares the actual WVM RHS with direct signed Fourier convolution on two quadrature grids and an independently refined EVP. It uses the same canonical coefficient labels, including both conjugates; it does not project a separately refined initial condition into a different modal state. The error norm is the physical kinetic plus displacement-potential plus surface energy norm. The sum of individual convolution-term norms records cancellation and sets the absolute reference scale. Exact collinear zeros instead expose absolute error relative to the state's physical advection scale; no denominator floor turns them into a relative-accuracy claim. The maximum manufactured velocity is 0.03 m/s by default. Conservation work is reported both relative to the assembled source and relative to the sum of absolute individual source terms. In an APV-only state each boundary streamfunction is proportional to its anomaly, so boundary advection vanishes analytically; its roundoff-sized assembled source is not an appropriate conservation denominator. The individual-term scale is explicit, homogeneous, and uses no floor.

## Usage and cost contract

```matlab
addpath('tools/aliasing-study');
configureStudyPath(oceanKitRoot); % pinned exported dependencies
source = prepareSourceStudy(resolveStudyCase("cal-constant-17"));
prepared = prepareQGQuadraticAssessment(source);
report = assessQGQuadraticResolution(prepared);
second = assessQGQuadraticResolution(prepared,quadraticTolerance=.05);
assembled = assessQGAssembledTendency(source);
runQGQuadraticAssessmentStudy(newOutputDirectory);
```

Preparation reuses the existing source modes and reference grids with zero additional mode solves. It evaluates all APV/surface/bottom input pairs for the selected horizontal interactions, in one mode-pair batch at a time. Its default reservation limit is 500,000 scalar output measurements: three Cartesian/assembled channels times five output observations per input pair. This unit is explicitly different from the wave advisory's individual source-product count. The incremental workspace estimate is capped at 512 MiB; it excludes the already-owned source preparation and is an estimate, not a measured OS peak. The retained snapshot has no solver or model handle. Reassessment reads that fixed snapshot without new mode solves, products, or quadrature. Changing its physical inputs or reference budgets requires fresh preparation.

The calibration targets for the additional QG preparation are 2 seconds, 250 milliseconds for repeated assessment, and 64 MiB retained evidence. The explicit assembled-model driver and its independent references have separate timings; they are not included in the inexpensive snapshot reassessment claim. Source preparation still constructs the existing wave inventory; this increment reuses that work and does not optimize away provider solves.

## Coverage and evidence

The reference study uses a 10 km square domain, 1000 m depth, a 6² horizontal grid, three APV modes, both boundaries, constant N² = 10⁻⁴ s⁻² or N² = 10⁻⁴ exp(2z/D) s⁻², and f = 10⁻⁴ s⁻¹. Vertical grid refinement holds physical parameters and retained APV/boundary families fixed. The two EVP orders and reference quadrature orders are recorded in the evidence configuration.

The reports distinguish sampled-product acceptance, fixed-boundary acceptance, APV grid support, reference qualification, and output-page coverage. An `assessed` status covers the specified sampled inventory only. A missing positive output page is inconclusive. Individual mean-output Cartesian channels are omitted because QG has no independently evolved mean APV family; the direct assembled convolution checks their exact Jacobian cancellation. MDA inputs, wave-coupled dynamics, arbitrary superpositions, trajectories, and exhaustive interaction certification remain outside this increment.

[Recorded evidence](Issue426/) includes vertical refinement, small dense controls, repeated-call costs, manufactured states, the resolved product inventory, reference flags, and verification. Constant-stratification localized exponential solutions independently check both boundary profiles; existing QG derivative, physical/signed-energy, single-active-boundary, restart and transfer tests protect the supporting operators.
