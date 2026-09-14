# T4: Dealiased nonlinear thermal QG evolution

Status: implementation plan for [#435](https://github.com/JeffreyEarly/wave-vortex-model/issues/435). T4 is not implemented. Start from the T3 commit containing this plan on `feature/v5.0-free-surface-qg`, recording its exact hash before implementation. T1/T2 supply the scientific state and projection; [T3](../Validation/Issue434/README.md) supplies qualified forced linear evolution and the shared ETDRK4 lifecycle. These are development-branch completions, not releases or default-branch merges.

Keep InternalModes `v2.0.0-beta.4` (`f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`) and the existing OceanKit snapshot graph. Preserve the experiment repository, case pins, historical references and unrelated local work.

## Intended outcome

Evolve a demonstrably nonlinear, complete thermal state through the existing model and integrator. The interior tendency is minus the horizontal Jacobian of streamfunction and QGPV; each active endpoint advects its own displacement anomaly using that endpoint's horizontal velocity. Retain every selected thermal direction, the existing small-surface-amplitude equations, both active endpoints and the independently represented mean. No APV projection belongs in the evolution path.

Start with unforced, zero-diffusivity f-plane controls to isolate nonlinear errors. Then combine nonlinear advection with T3 diffusion/seasonal evolution in a bounded compatibility test. Quadratic drag, damping selection, full restart, campaign throughput and long seasonal experiments remain T5/T6/T8/T10 work.

## Implementation sequence

1. **Define the nonlinear quadrature contract.** Add an explicit nonlinear construction/assessment path using `shouldCheckQuadraticAliasing=true`, retaining linear-only construction with false. Give nonlinear quadrature count and acceptance tolerances distinct names and evidence from native sampling and linear assembly. Evaluate polynomial/WKB fields and variable-coefficient factors directly on the product quadrature. Compare fixed-space products against independently refined quadrature; do not treat a generic 3/2 polynomial rule as proof for the mapped operator. Store the accepted policy/settings needed to reproduce evaluation; keep derived maps transient. If the canonical schema needs extension, version it and preserve cheap restoration of T2/T3 linear snapshots with explicit linear-only defaults, without a scientific solve.
2. **Separate native source and product projection.** Reuse T2's left dual, endpoint terms and normalization, factoring a shared internal weak-pairing worker where needed. The public native-grid source projector must retain its current behavior. Nonlinear products use a quadrature-aware internal path: integrate on the product grid before reducing to retained coefficients. Do not form high-degree products on the native grid or downsample them before projection. Keep surface and bottom sources separate and evaluate their endpoint maps directly.
3. **Implement the shared nonlinear RHS.** Adapt `WVNonlinearAdvection` and the thermal tendency/forcing interfaces at a narrow boundary. Reuse horizontal differentiation, compact Fourier support, masks and field reconstruction; require the qualified horizontal dealiasing policy for supported nonlinear runs. Share one physical reconstruction per RHS where possible and batch equal-radius maps. Separate the independently overintegrated nonlinear contribution from ordinary native-grid external sources. Remove only roundoff means of the nonlinear Jacobians after measuring them; never erase externally supplied source means. MDA remains horizontally uniform and receives zero Jacobian mean.
4. **Connect the existing controller.** Replace T3's unconditional linear-only rejection with a capability check for a qualified nonlinear inventory and explicit nonlinear-advection registration. Preserve `thermalLinearDynamics=true` as an explicit linear mode that cannot silently evaluate registered nonlinear physics: reject contradictory configuration or explicitly exclude that process through a documented rule. Nonlinear runs use the same ETDRK4 controller, total physical-state norms, CFL caps, accepted-state recovery and output sampling. Diffusion and the analytic seasonal source remain excluded from explicit stages exactly once. Unqualified products and unsupported closures must still reject.
5. **Qualify and measure.** Add manufactured thermal controls, a bounded nonlinear evolution study and a reproducible per-RHS measurement utility. Keep numerical acceptance separate from timings. Record reconstruction, products and projection timings, equal-radius batch use, array sizes and peak scratch estimates; label estimates as such if actual allocation instrumentation is unavailable. Report the workload, precision, thread count and warm-up procedure. Do not infer whole-model speed from a kernel timing.

Use the existing `tools/aliasing-study/prepareQGQuadraticAssessment`, `assessQGQuadraticResolution`, `assessQGAssembledTendency` and `WVInternal` product/reference kernels for physical controls and measurement plumbing. Their APV-specific state builders, duals and norms require thermal adapters; do not copy their assumptions or route thermal coefficients through their APV inventories.

## Acceptance gates

| Gate | Required evidence |
| --- | --- |
| Analytical Fourier interactions | Nonparallel signed wavevector pairs with nonzero Jacobians; verify sum/difference interactions, conjugates, amplitudes, reality and mean cancellation |
| Vertical projection | Low/high polynomial and mixed interior/boundary states; direct signed Fourier convolution with independent finer physical quadrature agrees in retained physical tendencies |
| Resolution accounting | Refine native sampling, product quadrature and thermal bandwidth separately; distinguish aliasing into retained directions from unrepresented physical content |
| Endpoint/gradient behavior | Separate surface and bottom tendency errors plus near-surface buoyancy-gradient diagnostics; no combined endpoint metric hides a failure |
| Nonlinear dynamics | Nonzero evolution in an unforced nondiffusive run; convergent physical energy/invariant residuals under independent time and space refinement |
| Null/mean controls | Parallel-wave zero-Jacobian cases only as null controls; signed MDA preservation and zero Jacobian mean demonstrated independently |
| Integration compatibility | T3 exact seasonal controls remain passing; nonlinear-stage rejection/failure restoration and observation-cadence invariance remain covered |
| Performance accounting | Representative per-RHS component costs and scratch memory with workload metadata, without a throughput claim |

Before evaluating results, declare tolerances for each physical observable and the independent reference budget in the assessment configuration. Derive scales from manufactured amplitudes and numerical conditioning; do not invent a universal relative threshold near exact cancellation. Require reference differences to consume at most one fifth of their corresponding allowance. Report uncovered interactions as inconclusive. The 257/385 linear success is not a nonlinear resolution prescription.

For invariants, derive which quantities the selected weak projection conserves discretely. Measure energy, QGPV variance and each endpoint-anomaly variance as applicable; distinguish an exact discrete identity from a converging truncation residual. A stationary null test or a merely stable trajectory is insufficient. Do not adjust the physical operator to manufacture a conservation result.

## Verification and handoff

Use clean `configureCIEnvironment` setup and verify exclusive beta.4 provider resolution. Run new focused nonlinear tests, the affected thermal construction/source/cache and T3 integration tests, and existing APV/shared RHS regressions. Run the bounded scientific controls, Code Analyzer on changed MATLAB files, one coherent documentation generation/check cycle when canonical sources change, runtime-layout and whitespace/scope checks. Read the profiling guide before collecting timing or memory evidence. Record exact commits, commands, measurements, blocked checks and missing assets in `Documentation/Validation/Issue435/`.

T4 completion enables qualified nonlinear thermal advection. It does not enable an arbitrary closure or authorize campaign reruns. T5 next supplies strict physical forcing/drag parity; T6 chooses and qualifies damping on the complete thermal state, and T8 qualifies complete persisted continuation.
