# T10 decisions and bounded campaign follow-up

Use the [final T10 report](README.md) as the authority for the supported configuration, completed gates, missing references and resource measurements. This handoff proposes the next bounded scientific work; it does not authorize a seasonal production run. The existing [experiment E2 issue](https://github.com/JeffreyEarly/free-surface-qg-experiments/issues/2) requires a T10 READY configuration before its three-cycle qualification and longer extensions. A conditional result supports resolving named prerequisites, not treating that entry gate as satisfied.

## Configuration and decisions to retain

The candidate is **64×64×385, 257 complete thermal directions, four mean modes, 2,057 assembly points and 769 nonlinear product points**, retaining the fixed physical laws and both endpoints. Use InternalModes beta.5 or later and store the exact tested package graph. Runner adoption should consume the existing transform, forcing, integration and annotated-persistence interfaces.

The fixed-space 769/1537/3074 comparison passes all 81 six-hour trajectory rows and all 36 initial-state checks on the named manufactured stress fixture. The scientific maps and physical laws are held fixed; only product sampling and its assessment metadata change. This supports the lower product rule on that representation and window, not arbitrary future high-mode states. The [closure/product audit](ClosureAudit.md) preserves the evidence and scope. Exact 769-point complete-workload, dense-budget and provider-free restart results belong to the final report; their outcome is not presumed here. Likewise, completed 1537-point spatial comparisons retain their original identities and limitations.

| Decision | Reason and next condition |
| --- | --- |
| Prefer no optional damping | Use it while the named accuracy, budget and stability gates pass. Physical diffusion and bottom drag remain active. |
| Retain horizontal-only damping as a fallback | It passes the five-percent short-window bias screen, but barely acts on this fixture. A developed cascade requires its own bias/activity evidence before adoption. Preserve the same physical cutoff when transferring resolution. |
| Exclude the tested six-mode vertical APV taper from the pilot recommendation | It produces positive physical energy work and differences of 32.53% in QGPV and 11.68% in the upper-layer buoyancy gradient, exceeding the declared bias screen. Increasing coordinate damping is not a demonstrated remedy. A different energy-dissipating vertical closure would be a separate design task. |
| Keep offline diagnostics independent | Start with 64 APV modes on 129 stored diagnostic depths and 513 physical integration points, using the qualified finer-basis/quadrature checks. This does not change native evolution sampling or the six-mode historical damping definition. |
| Separate M10 and M100 decisions | The 0.1 m/s manufactured stress fixture reaches recorded displacement/depth 1.318. It tests numerical behavior outside a credible small-displacement seasonal interpretation and cannot stand in for mature M100 evidence. |

## Proposed bounded extension toward E2

1. **Close the named entry gaps.** Review the final report's exact 769-point no-optional-damping workload, budget and restart results, together with time, mean and spatial references. Preserve failed or memory-limited rows. Resolve an entry-blocking uncertainty with one targeted comparison. Freeze state/forcing identities, step policy and diagnostic basis before a new trajectory; reuse unaffected shared-interface verification.

2. **Start from the physical cold M10 case.** Use time zero, zero QGPV and mean, the deterministic 1 cm RMS surface seed and original annual source phase. Reuse matching completed cold-start checks. Proposed checkpoints are one day, seven days, then separately budgeted progress toward the first source maximum. Record each target and wall limit. Preserve the forcing year, diffusivity and seed; reaching one source maximum does not cover a full cycle.

3. **Qualify the states that emerge.** Save a small set around startup, nonlinear activity, source zero and source peak. Use the accepted advection-disabled companion trigger, occupied horizontal/thermal tails and triggered mean-mode control, retaining transfer/reference uncertainty. Diagnose actual records with the saved APV basis and refined quadrature, including both endpoints and physical cross terms. A capacity-only manufactured record does not fill a missing seasonal regime.

4. **Gate extension on budgets and applicability.** Retain denser budget observations where needed. Stop on nonfinite state/inventories, step underflow, ten consecutive rejections, or the configured memory/wall limit. More than 20% rejections flags throughput investigation. Hold scientific extension for an inconclusive required budget/reference or order-one displacement/depth, relative vorticity/f or surface slope. Record maxima as sampled diagnostics. Start a separate cold M100 trajectory only after reviewing M10 prerequisites and resources; the manufactured stress case supplies no mature-flow applicability evidence.

5. **Set production limits before expanding the horizon.** Campaign wall time, disk use and checkpoint/analysis overhead remain unaccepted. Propose limits from the exact candidate's startup and active-state measurements. Budget scalar `T/384`, coefficient `T/48`, denser budget observations and a small field-snapshot set. Separate logical payload from allocated growth, including checkpoint copies and analysis workspace. Three cycles and 1/5/20-year extensions remain separate E2 execution decisions.

## Memory and one narrow runtime follow-up

Run MATLAB serially in fresh guarded processes, release owned models/transforms before building another large cache, and retain accepted-state checkpoints persistently. Completed 64-grid measurements are roughly 15 GiB of sampled family footprint; the [physical metric cache](../../../@WVTransformFreeSurfaceThermalQG/physicalMetricOperators.m) is a major cost. The accepted 32 GiB reporting ceiling bounds declared probes; retain lower operational cutoffs where sufficient. A cutoff leaves a reference inconclusive. Cache compaction is separate from reporting this limitation.

One failure-only issue remains in [WVModel.modelFromFile](../../../@WVModel/modelFromFile.m): model construction at line 28 and the output-restoration catch at lines 35–39. If observer restoration throws, the factory closes its NetCDF handle but does not explicitly delete the partial model/transform; the caller never receives them. Add exception cleanup whose ownership is relinquished on successful return, with one forced-restoration-failure resource-release test. Preserve successful behavior, persistence format and provider-free restoration. This is a narrow fix, distinct from the passing continuation checks in [Audit.md](Audit.md).

Preserve historical APV pins and output directories throughout runner adoption. New product counts, closure choices, resolutions or physics require fresh case directories and provenance; never append a revised operator to an old trajectory. The finite-amplitude model investigation and any new vertical closure remain separate from this bounded E2 prerequisite work.
