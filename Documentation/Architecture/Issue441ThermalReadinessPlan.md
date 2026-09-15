# T10: Nonlinear accuracy, throughput and campaign readiness

Accepted implementation plan for [#441](https://github.com/JeffreyEarly/wave-vortex-model/issues/441), 14 September 2026, including the subsequently approved horizontal-only damping comparison. The user selected **this Mac** for throughput and campaign time/storage estimates. T1–T9 are closed. The mode-capacity follow-up [#527](https://github.com/JeffreyEarly/wave-vortex-model/pull/527) merged into v5 at **`abe98510ba3ad24276c2af2bd89c80b24209b568`**. Recheck that revision and prerequisite state before implementation.

The outcome is a reproducible configuration, measured limitations, a local time/storage estimate, and a READY, CONDITIONAL or NOT READY decision. T10 is a bounded qualification of the implemented model. A useful negative or conditional answer completes the measurement; it does not justify silently relaxing criteria or starting an unrestricted optimization project. Long 20-year production cases belong to E2.

## Fixed scientific configuration and starting choices

| Item | Starting configuration |
| --- | --- |
| Domain and latitude | 500 km square, 4 km deep, 24 degrees |
| Stratification | `N2(z)=(5.2e-3)^2*exp(2*z/1300)`; fixed in time |
| Diffusion | Scalar `kappa_z=1e-5 m2/s`; insulating at both endpoints; zero-diffusion mechanism control |
| Seasonal source | Annual meridional mode 5, `M*pi/T*sin(10*pi*y/Ly)*sin(2*pi*t/T)`, M=10 and 100; strict surface-displacement tendency only |
| Bottom stress | Existing quadratic law, `Cd=1e-3` |
| Fresh experiment | t=0, zero interior QGPV and mean anomaly, deterministic 1 cm RMS surface displacement; normalize one common-support T8 seed once, transfer it and record fit residuals |
| Thermal directions | 257 candidate, 385 refinement; preserve the historical 129-direction linear failure |
| Horizontal grids | 32 as an inexpensive screen, 64 as the intended candidate, 96 as a bounded finer comparison |
| Native thermal samples | Start from 385; compare stored sampling separately. Use a common 513-depth evaluation when comparing thermal bandwidths |
| Mean family | Start with four MDA modes; run the mixed-mean 4/8 control and repeat on campaign windows when the mean exceeds the declared materiality threshold |
| Offline diagnostics | Start with 64 APV modes, 129 stored diagnostic depths and 513 physical integration points; requalify on the actual 64-grid support and representative states |
| Integration | Existing WVModel exponential integration, exact homogeneous diffusion/seasonal treatment and current adaptive/stability contracts |
| Host | This Apple M5 Max Mac, 18 physical/logical CPU cores and 48 GiB installed RAM; runtime baseline R2026a Update 4 |
| Dependencies | InternalModes beta.5 minimum, using OceanKit `1873071fe2dfc2678490df1b0252e5071e9d9715`; record all snapshot versions and unique symbol resolution |

The historical [T9 mode-capacity result](https://github.com/JeffreyEarly/wave-vortex-model/blob/7680110e93a123b5d65b08792ed928fec4e7c221/Documentation/Validation/Issue440/ModeCapacity/README.md) is a starting choice, not a universal grid rule. It was measured on an 18-grid. Increasing horizontal bandwidth can require more vertical sampling for fixed endpoint responses even when the APV count stays fixed. If 129 diagnostic depths fail on the 64-grid, compare the same band on 257 depths; report the limit and cost rather than automatically returning to 1025. Keep the offline diagnostic band independent of the online damping band.

The historical experiment repository remains a comparison/provenance source. Its current APV runner pins WVM `4ec07256476ee57ceee23d70422baec65d1f31a4` and InternalModes beta.4. Do not rewrite those dependencies or existing case pins. New thermal qualification uses the beta.5 graph above, with separate output directories. Runner adoption and repository naming are not needed to complete T10 in WVM.

## T10a: Freeze the harness, cases and measurement contract

Implement an authoring driver with a declarative case manifest, explicit observation times, checkpoint boundaries and append-safe result tables. Proposed entry points are `tools/qualifyThermalReadiness.m` and `tools/benchmarkThermalWorkload.m`, backed by small shared authoring helpers only where multiple drivers need identical case construction or comparison. Reuse `qualifyThermalNonlinear`, `thermalConvolutionReference`, `qualifyThermalDiagnostics`, `auditThermalDampingEnergy`, `qualifyThermalCampaignRestart`, `qualifyThermalAPVModeCapacity` and `analyzeThermalAPVOutput` for the contracts they already establish. Do not copy their scientific operators or invent another model/integrator hierarchy.

Parameterize the existing authoring fixtures where their fixed choices differ from this study. In particular, T8's 18-grid restart case constructs a four-mode APV basis on at least 513 depths; neither that grid nor that diagnostic cost is an inherited T10 requirement. Construct and save the online closure basis and offline diagnostic basis separately. Thermal diffusion stays owned by the thermal transform/integrator, with the seasonal source registered once; copying an APV runner's additional vertical-diffusivity forcing would double-apply the thermal diffusion.

The initial case set is deliberately small:

1. A constant-stratification nonparallel interaction control, including both endpoint anomalies and a mixed mean, to connect the independent Fourier-convolution reference to the new harness.
2. A fresh seasonal cold start for M=10 and M=100, initially one model day. This checks actual initialization, clocks, source semantics, output and integration; weak startup advection is not representative throughput.
3. A deterministic nonparallel developed-flow control at 0.01 m/s, with a 0.1 m/s stress variant. Reuse the bounded T6 precursor or generate a short reproducible precursor in a new case. Initial pressure, projected state, normalization and all clocks are stored.
4. Short developed-flow windows at zero and peak seasonal tendency, including M=100. A manufactured state at a declared seasonal phase is explicitly labeled as such; it is not presented as a fresh experiment or a genuine seasonal spin-up.

Start developed windows at six model hours. For the selected nonlinear control, compare against a short companion with advection disabled but identical initial state and other processes. Call nonlinear evolution measurable when the nonlinear/companion difference in QGPV or horizontal velocity exceeds five times that observable's complete spatial allowance at a declared observation time. If this trigger is not met, extend once to three model days only when the measured cost fits a 30-minute case block and the remaining study budget; otherwise label the activity check inconclusive. A stronger manufactured control receives a new case identity and fixed amplitude before its qualification run. Weak windows still support mechanism/lifecycle checks.

Always perform the mixed-mean 4/8 control. In campaign windows, repeat it when a supported horizontal-mean observable exceeds the larger of five times its absolute field floor and 1% of that observable's full-field reference norm. Record this threshold and the corresponding mean budget before comparisons. A stable window completes its requested interval with finite coefficients, fields and physical inventories, obeys the existing CFL/damping restrictions, and avoids step underflow or ten consecutive rejected steps. More than 20% rejected attempts is a throughput flag to investigate, not an automatic claim of physical instability. Growth and closure work still have to pass the separate reference/budget tests; these checks alone cannot certify stability outside the measured interval.

Freeze a case/configuration hash, full scientific/forcing arrays, dependency revisions, MATLAB/CPU/thread details, host load, target horizon and tolerance table before final qualification. Exploratory failures remain in a development ledger. A case that changes an operator, grid, band, closure or seed gets a new identity; it is never appended to an earlier trajectory.

## T10b: Establish accuracy with one-axis comparisons

Run short comparisons from the same physical initial state at the same physical times. Define each paired comparison from one authoritative state on Fourier support shared by both grids; normalize that state once on the common physical quadrature. Transfer/truncate using the existing compatible transform/projector contracts, then verify common-support physical fields and Fourier amplitudes. Thermal eigenvectors can differ across dimensions, so raw thermal coefficient equality is not the invariant. Initial transfer loss must consume at most one tenth of each complete spatial allowance; larger loss is a separately reported representation failure, not trajectory error. Preserve the T8 cold-start QGPV/endpoint fit checks where applicable. Do not independently RMS-normalize each target grid. A fine-state case with initially unresolved coarse support is useful but must be labeled separately from this matched-initial-state comparison.

Use a common positive physical quadrature and common horizontal Fourier support for paired field errors, and report energy/tails outside that support separately. This prevents unavailable coarse modes from being counted as numerical roundoff or silently omitted from the resolution assessment.

| Axis | Bounded comparison | Held fixed |
| --- | --- | --- |
| Time | Three actual step levels h, h/2, h/4, plus the chosen adaptive configuration | State, physics, spatial representation, product rule and observation times |
| Product sampling | Qualified product count Qp and a doubled reference at fixed thermal dimension | Scientific thermal maps and horizontal grid |
| Thermal bandwidth | 257 and 385 directions, with one additional reference refinement only if needed | Common native/evaluation sampling, sufficiently qualified common assembly/product quadrature, physical closure law |
| Native sampling | 385 and 513 samples at fixed 257 directions | Thermal dimension, assembly and product quadrature |
| Horizontal bandwidth | 32/64 screen, then 64/96 on selected windows | Stratification, vertical representation and physical filter law on common wavenumbers |
| Mean bandwidth | Four/eight mixed-mean control, then campaign windows exceeding the materiality threshold | Other counts and physics |
| Diagnostic sampling | T9 band/grid method on actual horizontal support; Q/2Q on recorded states | Evolved state and online closure |

Do not run the Cartesian product. Establish time and product accuracy on a few representative states, screen candidate spatial choices, then repeat only the winning configuration's integrated checks and the comparison needed to estimate reference error. For 257/385 bandwidth comparison, use one common accepted assembly and product rule; derive counts from the existing factories and qualification assessments rather than interpreting `Nz` as the polynomial dimension. Initial common candidates are 2057 assembly points and 1537 nonlinear product points, reduced only in a separate fixed-space sampling study if that cost matters. Retain a doubled-rule check where the scientific reference needs it.

Configured maximum steps can be ineffective when both exceed a CFL or explicit-damping bound. Record accepted steps, rejected attempts, active restrictions and error estimates. A nominal h/h/2 pair that produces the same accepted step sequence is not a temporal refinement. Tighten the actual step bound or tolerance until the comparison changes the stepping in the intended way.

Use independent Fourier-convolution/assembled-tendency references for bounded instantaneous cases. Trajectory references use genuinely finer time/space representations with a further refinement estimate. Refine both comparison numerators and source/reference norm denominators. If reference uncertainty exceeds its allowance, the result is INCONCLUSIVE; allow one targeted refinement, then report the limitation instead of growing the study indefinitely.

Pointwise trajectory comparisons apply to the declared short windows. Longer nonlinear pilots use physical inventories and time-resolved or windowed statistics as well; chaotic trajectory separation must not be mislabeled as a simple discretization error or ignored without documenting the comparison interval.

## Proposed accuracy and reporting gates

These are proposed T10 engineering/scientific reporting allowances to freeze at T10a. They do not replace stricter existing constructor, algebraic, forcing, persistence or T9 implementation tests. Use `absoluteFloor + relativeAllowance*referenceNorm` per observable; never combine the endpoints into one surface-dominated norm.

| Observable | Spatial/window allowance | Absolute floor |
| --- | ---: | ---: |
| QGPV RMS difference | 1% | `1e-12 s^-1` |
| Buoyancy RMS difference | 1% | `1e-10 m/s2` |
| Horizontal velocity RMS difference | 1% | `1e-7 m/s` |
| SSH and surface anomaly, separately | 1% | `1e-4 m` each |
| Bottom anomaly | 1% | `1e-5 m` |
| Positive physical energy-norm state difference | 1% | `1e-6 m^(3/2)/s` |
| Near-surface vertical and surface horizontal buoyancy-gradient differences | 5% | `1e-11 s^-2` each |

Temporal and initial-transfer error should consume at most one tenth of the complete corresponding spatial allowance (absolute plus relative). Reference error and comparison-quadrature uncertainty must each consume at most one fifth of the effective allowance for that comparison, including the tighter temporal/initial-transfer allowance. Use a fixed upper-200-m region for the near-surface vertical-gradient comparison. Compare integrated energy, enstrophy and each endpoint budget using a cancellation-aware scale: the maximum of the initial inventory, absolute inventory change and sum of absolute integrated process work. Proposed budget residual allowance is 0.2%, with independently refined budget sampling and absolute inventory floors derived from the stated field floors and physical integrals. Record those floors explicitly in the frozen manifest. A near-zero scale retains absolute units and an explicit undefined relative value; it does not automatically pass.

For offline diagnosis, preserve the T9 implementation gates and separately report sampling stability, APV mode labels, QGPV/energy/endpoint residuals and physical cross terms. No requirement that the diagnostic residual be tiny: the question is whether the diagnostic is trustworthy and useful at its stated cost. Polynomial/APV/horizontal tails guide investigation; a tail alone is neither a proof of resolution nor a reason to silently increase damping.

The minimum diagnostic record set is the cold-start state and developed states at zero and peak seasonal source for each M case proposed for readiness, including a state with a nonzero mean. Retain case/record identifiers and seasonal phases in the ledger. Qualify the same APV band against a finer stored basis, test Q/2Q stability of coefficients, residuals and source norms, record conditioning, and check both fixed endpoint responses at every retained horizontal radius. Reuse a basis qualification across states with identical scientific configuration, but repeat state-dependent quadrature checks on the named records. Preserve the T9 1% physical mode-shape/reporting allowances and stricter implementation gates. An unmeasured required regime leaves that M case CONDITIONAL; large, reliably computed projection residuals describe diagnostic coverage rather than a failed transform.

## T10c: Make the closure decision explicit

Screen three configurations on the intended horizontal grid: no optional damping; horizontal-only damping with the same scalar rate applied to every thermal direction at each horizontal wavenumber; and the existing named `WVThermalAPVDamping` candidate with its recorded six-mode band and `apvCutoffFraction=.5`. All retain physical diffusion, bottom drag and the seasonal source. Keep the cutoff/band definition and generalized endpoint weights explicit; the offline 64-mode diagnostic must not silently become a 64-mode damping law.

For horizontal-only damping, the common nonnegative decay rate r(k) gives dE(k)/dt=-2*r(k)*E(k), preserving cancellations between APV and boundary contributions. Reuse the existing scalar filter, stage-speed and family/forcing interfaces; first determine whether an authoring configuration of the existing canonical closure suffices. Avoid a new runtime class or public flag unless required for correct execution. Verify the actual energy work, zero vertical tendency, frozen physical filter transfer and annotated restoration. Any unused APV setup/application overhead in an authoring configuration must remain visible in performance attribution.

Preserve the same physical damping law across spatial comparisons. `forcingWithResolutionOfTransform` already transfers the frozen horizontal resolution/cutoff and APV arrays; use that contract. Regenerating a grid-dependent cutoff independently on each grid changes the model and must be a separately labeled closure comparison, not the horizontal-convergence estimate. Verify explicitly that seasonal mode 5 lies below the chosen horizontal damping onset on the intended grid.

Freeze the six physical APV labels, basis arrays, inversion factors, vertical rates, horizontal onset/cutoff and endpoint weights in the manifest. Verify exact identity of stored canonical closure parameters after transfer, then compare rates at common physical wavenumbers using the same prescribed velocity scale. Compare mapped tendencies for the shared state in common physical coordinates within the initial-transfer allowance; do not compare incompatible raw thermal coefficient arrays or allow a gridwise change in the velocity scale to masquerade as a changed filter. Keep the no-optional-damping, horizontal-only and named-APV-damping horizontal-convergence results separate.

The existing vertical closure can inject physical energy. Record horizontal and vertical work separately, the actual stability cap, closure-induced state changes and tail behavior. A proposed 5% allowance on the declared paired-window observables provides a bounded bias screen, not a theorem that such a closure is appropriate for every campaign. Positive vertical work must be disclosed and interpreted; it must not be hidden by negative horizontal work or relabeled as a dissipative law.

Prefer no optional damping if it remains stable and passes the accuracy checks; otherwise prefer horizontal-only damping if it passes. Retain the named vertical APV candidate as an explicitly identified historical comparison with measured consequences, rather than assuming stronger coordinate decay solves a physical-energy problem. If vertical numerical damping proves necessary, return a conditional/negative readiness result and specify a separate closure designed to dissipate the positive physical energy while protecting declared large-scale/boundary structures. Such a law generally changes the independent APV decay rates. Designing it or sweeping many bands/cutoffs is outside this increment.

## T10d: Verify budgets, output and restart on the chosen configuration

Use the ordered `coefficientTendency` process breakdown already used by integration. Integrate those rates at their actual observation times; snapshots alone do not establish a time-integrated process budget. Check budget-sampling refinement separately from step refinement, including startup and peak source/stress windows. Preserve signed diffusion/closure work and all T9 component cross terms.

Reuse the committed-record protocol and T8 fresh-process continuation. Run uninterrupted versus checkpoint/restart continuation at the actual candidate grid and nonzero flow, including a checkpoint near an output boundary and the existing staged-tail case. Verify fields, canonical coefficients, clocks, forcings and committed prefixes against existing restart tolerances. Restore with InternalModes scientific construction unavailable, then diagnose restored records using a separately saved diagnostic basis. Measure restart/read/write cost and checkpoint size; no changed operator is resumed into an old case.

Start cadence estimates from the existing runner: scalar diagnostics at T/384 and coefficients at T/48. Use denser, explicit startup/active-window budget observations where necessary, then qualify the selected cadence. Record extra output RHS evaluations used to reconstruct intermediate observation times; explicit integration-call boundaries can also shorten accepted steps. Save full three-dimensional fields only for a small declared snapshot set; ordinary modal analysis uses coefficients and cached maps.

## T10e: Measure the complete workload on this Mac

Record cold scientific setup, restoration, first-call preparation and warm integration separately. Benchmark actual WVModel integration with the selected forcings, diagnostics, output and restart; also measure integration alone to attribute overhead. Record accepted/rejected steps, stage/RHS counts, active timestep restrictions, simulated seconds per wall second, checkpoint/read/write timings, total bytes and diagnostic cadence.

Use a short 1/2/4-thread screen on the same warmed representative workload, then fix the thread count for comparisons. Timing trials run serially under recorded host load; parallel agents may work on code or review but must not contaminate the performance interval. Use repeated short batches and report their range, not an unsupported single precise campaign speed.

Measure process peak resident memory in a fresh MATLAB process with the host's process accounting, separating it from retained-array bytes and MATLAB per-function allocation statistics. This Mac has 48 GiB; propose a 32 GiB peak-MATLAB working budget to leave room for macOS and interactive work. Record memory pressure and swap behavior. A workload that fits numerically but causes sustained memory pressure is not the recommended local configuration.

Profile only after a representative complete-workload measurement identifies the cost. Attribute dense thermal reconstruction/projection, vertical transforms, Fourier products, scalar propagation, allocations, output and diagnostics separately, using the shared OceanKit profiling helpers. Reuse present field/endpoint and cache APIs; #453 is already closed for the Boussinesq selective-reconstruction work, while #452's FFT-backed derivative study remains open. Neither is a new prerequisite, and their status does not imply a measured thermal speedup.

The recovered workload profile identifies the 1537-point nonlinear reconstruction/product/projection as the dominant warm RHS cost. Invoke the allowed separate fixed-space sampling study with 769 product points as a lower candidate, the original 1537-point rule as reference, and 3074 points to estimate reference error. All thermal/mean directions, assembly arrays, native sampling, physics and tolerances remain fixed. This is a bounded configuration comparison; adopting the lower rule requires its own measured gates and new case identity.

Allow one bounded improvement cycle for a dominant measured bottleneck: batching, avoiding an unnecessary allocation or repeated reconstruction, or correcting invalid cache reuse. It must preserve scientific equations and pass the affected shared tests and before/after physical comparisons. GPU work, a new C++ backend, new transform hierarchies and open-ended tuning are separate issues.

Compare against the pinned APV baseline in an isolated dependency environment. Preserve its beta.4 graph and histories. Where optional damping laws differ, first use a short matched-physics no-optional-damping comparison; label other comparisons as different closures. An underresolved APV result remains a cost/accuracy comparison point, not truth. Equal `Nz`, coefficient counts or output cadence alone do not establish matched physical accuracy.

## T10f: Decide readiness and hand off a bounded campaign configuration

Estimate time for 1, 5 and 20 model years for each proposed M case, and the combined 20-year M=10/M=100 workload used by the current runner. Include setup amortization, observed step/rejection variability, scalar and modal analysis, I/O, restart and storage. Use startup and active-flow ranges; do not extrapolate a quiet cold start as the entire campaign. Report capacity requirements from actual bytes per record and the proposed cadence, including checkpoint copies and temporary analysis overhead.

The initial qualification is bounded by a proposed four-hour compute budget on this Mac, organized into restartable case blocks of at most 30 wall-clock minutes. The first implementation checkpoint should take at most a ten-minute workload sample plus setup and targeted checks. These limits were accepted with the instruction to proceed; they bound qualification rather than production execution. If a reference cannot fit, record the resulting uncertainty and stop that axis. No unbounded annual or multi-year run is implied.

After the Mac stalled and restarted during the combined benchmark/lifecycle process, raw temporary artifacts must be regenerated in a persistent workspace evidence directory. Run one MATLAB job at a time under the external physical-footprint and time watchdog. Use an 8 GiB cutoff for small controls/construction and initially 16 GiB for the actual-grid workload; release each owned model before constructing another diagnostics cache. These operational cutoffs are more conservative than the proposed 32 GiB reporting ceiling. A stopped refinement is inconclusive and cannot be reported as passing.

The four-hour study budget does not define acceptable production cost. Report numerical readiness and local resource feasibility separately. The proposed 32 GiB MATLAB memory ceiling is a local feasibility gate, but the user has not chosen acceptable campaign wall time, total disk use or restart/checkpoint overhead for the 1/5/20-year horizons. Until those limits are explicitly recorded, resource readiness and the combined production recommendation remain CONDITIONAL even if the numerical checks pass. Use the first measured sample to propose concrete limits and a cadence/horizon tradeoff before any production decision; do not choose acceptance limits after seeing the final result.

After the short-window gates, attempt one true forcing-cycle M=10 pilot only if the measured estimate fits the declared remaining qualification budget. Do not compress the year, change diffusivity or rescale the source to make that trajectory cheaper while calling it the same campaign. If a full cycle or the strong-forcing regime is not covered, make the readiness scope conditional and assign a bounded E2 extension. M=10 and M=100 may receive different decisions.

Report maximum displacement/depth, relative vorticity/f and surface slope over the measured windows, especially for M=100. Order-one values flag the applicability of the small-amplitude QG assumptions separately from numerical convergence. T10 does not introduce the finite-amplitude corrections tracked in #451 or interpret a finite, well-resolved trajectory as proof of physical validity.

- **READY:** the named configuration passes the declared finite-time accuracy, lifecycle, diagnostic and resource criteria over the demonstrated regimes, with an explicit E2 horizon and monitoring policy. This is not proof of all future chaotic trajectories.
- **CONDITIONAL:** a useful tested configuration exists, but specified regime coverage, reference uncertainty, closure choice or resource limits require a staged E2 launch or a named prerequisite.
- **NOT READY:** a required physical, numerical, lifecycle or resource gate fails. Identify the smallest concrete next action; preserve the failed measurements.

Any result can close the bounded T10 measurement with complete evidence. Only a positive decision for an explicitly named configuration/horizon supports production execution; a conditional decision permits only its stated bounded follow-up. Long campaign execution and any resource-specific approval occur separately.

## Deliverables, delegation and verification

Keep the case manifest, machine-readable accuracy/reference/budget/performance/storage ledgers, binary trajectories, and checkpoints outside the repository with hashes and regeneration instructions. Record the supported configuration, explicit failures or inconclusive results, reproduction commands, and reviewed outcome on [issue #441](https://github.com/JeffreyEarly/wave-vortex-model/issues/441). Missing historical outputs must be named when needed; the core bounded controls remain self-contained and do not depend on an untracked literature asset.

Use three bounded workstreams: scientific references and comparisons; local workload/performance measurement; and restart/output/budget integration. The coordinator owns the frozen contract, closure decision and synthesis. Schedule MATLAB timing serially. An independent reviewer audits the final claims and shared-transform regressions before source changes are committed, pushed and merged. Avoid delegation around dependency or repository-communication rules.

Verification scales with the resulting changes: run the new bounded cases and directly affected existing thermal/APV/shared integration and persistence tests; Code Analyzer once on added/changed MATLAB files; one documentation check; whitespace, package-manifest/export scope and generated-artifact checks. Use clean minimum-version package/export tests when runtime or the promised supported package surface changes. Reuse completed T9 evidence where the behavior is unchanged. A necessary production correction receives the appropriate full integration gates; an authoring-only report does not automatically repeat the entire historical seasonal study.

The first reviewable increment is T10a plus one representative 64-grid workload sample, an actual-grid diagnostic qualification, and the closure/no-closure screen design. Its output fixes realistic run lengths and whether the full proposed matrix fits the budget before launching the remaining measurements. No long production campaign is started by approving this plan.

## Plan preparation verification

The merged baseline and prerequisite issue states were checked against GitHub. A separate reviewer audited the measurement contract; the draft now explicitly defines resource-decision limits, matched initial states, transferred closure checks, diagnostic regime coverage and numerical activity triggers. One clean beta.5-path `buildtool("docs:check")` passed with zero failures and no generated differences (2654 files, 5415 routes). Local Markdown links, whitespace and repository scope were checked after the review edits. Only this proposed architecture document was added; no MATLAB source, dependency snapshot, historical experiment, package export or website was changed. Code Analyzer and scientific qualification runs are implementation-stage checks and were not required for this prose-only plan.
