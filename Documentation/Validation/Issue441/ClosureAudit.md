# T10 closure and memory audit

The six-hour manufactured stress window supports retaining no optional damping as the first candidate. Horizontal-only damping meets its bounded bias screen but is almost inactive here. The named vertical APV closure exceeds that screen and injects positive physical energy. These observations do not establish campaign readiness: the initial displacement already exceeds the depth locally, several process budgets remain unresolved, and temporal/spatial qualification is separate.

This independent review inspected retained CSV/JSON evidence and authoring/runtime source on 14 September 2026. It did not run MATLAB or change physics. It supplements the [validation report](README.md), [independent audit](Audit.md) and [accepted plan](../../Architecture/Issue441ThermalReadinessPlan.md). Evidence paths below are relative to `OceanKitRepositories/thermal-readiness-t10-evidence`.

## Matched window and closure identity

`windows/closures/run-contract.json` identifies run `ca15868d8c83a03655356e07d4e46dbd495f0cf5e734918017fb21a585b86908`. All three cases use the 64×64×385 grid, 257 thermal directions, four mean modes, 2057 assembly points, 1537 product points, the fixed exponential profile and diffusivity, seasonal M100 at phase `pi/2`, bottom drag, and nonlinear advection. The manufactured initial velocity RMS is `0.1 m/s`. Nine observations cover 0–21600 s at 2700 s intervals. Each case completes 24 fixed 900 s steps, with 96 integration RHS evaluations, no rejected steps and no interpolated-output RHS evaluations.

All cases retain scientific hash `6f30b8071e7bca3e30443b10b1690567619506dead8eba6544769b16a590b1c8`. The 18 source-transfer preflight rows have exactly zero measured field difference and status PASS. The [comparison driver](../../../tools/compareThermalReadinessWindows.m) additionally checks scientific arrays, initial coefficients, physical configuration, integrator settings, observation times and execution identities before comparing the windows. The cases' execution IDs are distinct even where their initial-case identities agree.

The frozen online APV labels are 1–6, with `apvCutoffFraction=0.5` and per-speed vertical rates `[0,0,0,-5.285042907342582e-7,-4.123678973554764e-5,-8.4e-5] m^-1`. The physical horizontal resolution is `11904.761904761906 m`, and the onset is `1.2327480807967128e-4 m^-1`: horizontal mode 9.8099 on the 500 km domain. Seasonal mode 5 has wavenumber `6.283185307179586e-5 m^-1`, below that onset. The [horizontal authoring variant](../../../tools/thermalReadinessDamping.m) changes only the six vertical rates to zero and preserves the canonical arrays and physical filter. It still incurs the existing APV setup/application overhead.

## Five-percent bias screen

The comparison uses the [shared physical-field norms](../../../tools/compareThermalReadinessFields.m) at 513 and 1027 independent depth quadrature points. It retains separate endpoint norms, dimensional floors and full nonorthogonal physical-energy differences. For each observable, the complete bias allowance is `A = absoluteFloor + 0.05*referenceNorm`. Comparison uncertainty is `U = abs(error_1027-error_513) + 0.05*abs(referenceNorm_1027-referenceNorm_513)`.

A row is WITHIN BIAS SCREEN only when `U <= 0.2*A` and `error+U <= A`. It EXCEEDS BIAS SCREEN only when the quadrature is resolved and `error-U > A`; other rows are inconclusive. The overall screen exceeds its allowance if any row does. This screen compares changed closure physics; it does not supply the finer time/space reference needed for numerical convergence.

| Comparison | Rows within / exceeding / inconclusive | Largest error-plus-uncertainty / allowance | Six-hour consequence |
| --- | ---: | ---: | --- |
| Horizontal-only versus none | 81 / 0 / 0 | `3.07991e-6` | Largest relative field difference is velocity, `1.53998e-7` |
| Named APV versus none | 66 / 15 / 0 | `6.50540` | QGPV differs by 32.5270%; upper-200-m vertical buoyancy gradient by 11.6777% |

APV QGPV first exceeds the screen at 2700 s; the upper-200-m gradient first exceeds it at 5400 s. At 21600 s, APV differences in positive physical energy norm, buoyancy, bottom anomaly and surface anomaly are 0.292594%, 0.376203%, 0.155908% and 0.0544765%, respectively. These smaller differences do not override the two failed observables. Full rows are retained in `window-comparisons/{horizontal-none,apv-none}/field-comparisons.csv`.

## Signed work and budget limits

Work integrates the actual ordered process increments reported by `coefficientTendency`, contracted with the full physical metrics. The following positive and negative parts use trapezoidal integration of the positive and negative sampled rates separately. Sampling uncertainty is the absolute difference from trapezoidal integration on every second observation; it is a measured refinement indicator, not a rigorous bound between observations.

| Variant / channel | Positive energy work | Negative energy work | Net energy work | Sampling uncertainty |
| --- | ---: | ---: | ---: | ---: |
| Horizontal-only / horizontal | `0` | `-5.10760e-12` | `-5.10760e-12` | `9.14392e-14` |
| Horizontal-only / vertical accounting residual | `5.54600e-28` | `-1.24528e-28` | `4.30072e-28` | `1.05738e-28` |
| Named APV / horizontal | `0` | `-5.10760e-12` | `-5.10760e-12` | `9.14394e-14` |
| Named APV / vertical | `6.56529e-3` | `0` | `6.56529e-3` | `1.59420e-5` |

Energy work has units `m3/s2`, matching horizontally averaged, depth-integrated physical energy. Initial energy is `199.203699 m3/s2`; the APV vertical addition is about `3.30e-5` of that inventory. It is small in that measure but unequivocally positive at the recorded observations. Negative bottom-friction work, approximately `-0.0370661 m3/s2`, must not hide it. The APV decay rates are coordinate decay rates, not a guarantee of physical-energy dissipation.

The horizontal-only vertical callback is exactly zero. Its tiny reported vertical work comes from the existing process accounting: [coefficientTendency](../../../@WVTransformFreeSurfaceThermalQG/coefficientTendency.m) assigns the difference between the actual accumulated callback increment and the reported horizontal component to the vertical record. Floating-point accumulation therefore remains visible instead of being clipped or relabeled as a physical vertical law.

The named APV vertical channel also changes the other inventories:

| Inventory | Units | Positive work | Negative work | Net work | Sampling uncertainty |
| --- | --- | ---: | ---: | ---: | ---: |
| Potential enstrophy | `m/s2` | `6.88523e-7` | `-6.43976e-10` | `6.87879e-7` | `1.03334e-8` |
| Surface anomaly variance | `m2` | `11.5453` | `0` | `11.5453` | `0.0869211` |
| Bottom anomaly variance | `m2` | `0` | `-2225.6061` | `-2225.6061` | `2.91456` |

The full positive, negative and net horizontal/vertical records for all four inventories are preserved in both `signed-process-work.csv` files. Their raw small values remain unchanged.

`windows/closures/budgets.csv` records eight passing and four inconclusive inventory budgets. Energy and bottom variance pass for every variant. Potential enstrophy passes for none and horizontal-only, but APV sampling uncertainty `1.18977e-8 m/s2` exceeds one fifth of its `1.10297e-8 m/s2` allowance. All surface-variance budgets are inconclusive: sampling uncertainty is approximately `46.74–47.02 m2`, while one fifth of the `12.7322 m2` allowance is only `2.54644 m2`. Their residuals are also larger than the complete allowance, but the unresolved sampling prevents treating those residuals as established integration failures. A denser budget-observation run is a separate necessary check; the closure bias screen does not qualify those budgets.

## Regime and recommendation

The sampled maxima across all three windows are `max(abs(eta))/D = max(abs(eta_i))/D = 1.31822497`, `max(abs(vorticity))/abs(f) = 0.17186506`, and surface slope approximately `2.53702e-6`. Initial bottom RMS displacement is about 2301.5 m on the 4000 m depth. The order-one displacement flag is already active initially. These are maxima over recorded native grids and observation times, not continuous-space or between-observation bounds.

The short window populates very little of the horizontal damping band: its integrated horizontal energy removal is only about `5.1e-12 m3/s2`. Passing this screen shows little bias on this fixture; it does not show that horizontal damping controls a developed cascade. Likewise, low rejection counts do not establish nonlinear activity or seasonal maturity. Prefer no optional damping if the remaining numerical gates permit it; retain horizontal-only as the tested low-bias candidate if needed. Do not recommend this six-mode vertical APV closure for this window under the declared bias gate. Neither result authorizes a long physical campaign.

## Memory ownership and bounded reference execution

The revised [qualifier](../../../tools/qualifyThermalReadiness.m) stores paths to completed windows, clears each live `run`/snapshot collection after deleting its owned model and transform, and loads only the current comparison pair plus optional reference after releasing the authoritative source. Pair values are cleared after comparison. Preflight `initialRuns` is cleared before trajectory models are built. Caller-supplied scientific arrays and the authoritative initial source remain intentionally live during the trajectory phase. The source review found no remaining cross-case physical-metric cache retention in this path.

The failed original time block stopped at 16.3605 GiB sampled footprint; its two completed windows remain evidence, but it is not a completed block. The corrected `time-v2` block completes at 15.1781 GiB sampled footprint. The closure block completes at 15.1055 GiB, and its separate comparison process completes at 2.82595 GiB. OS-accounted child peak RSS is a different quantity; for `time-v2` it is 15.6393 GiB. These results are recorded in `recovery/{time,time-v2,closures,compare-closures}/result.json` and must not be mixed with pre-reboot temporary measurements.

The remaining large allocation is the intentional per-transform [physical metric cache](../../../@WVTransformFreeSurfaceThermalQG/physicalMetricOperators.m), which is required by the current inventory diagnostics. Its leading complex-double storage estimate is `16*P*(8*Q*N + 6*N^2)` bytes for radius count `P`, metric quadrature `Q` and thermal count `N`. At `Q=2057`, this estimates 11.17 GiB for `N=257,P=162`; 17.44 GiB for `N=385,P=162`; 24.19 GiB for `N=513,P=162`; and 23.23 GiB for the 96 grid with `N=257,P=337`. These are array arithmetic estimates, not process-memory bounds: scientific arrays, nonlinear/Fourier geometry, integrator state, scratch storage and allocation peaks add to them. Actual sharing and real/complex storage can differ.

Run each reference block in a fresh MATLAB process, with only one active trajectory model, an immutable evidence directory and the existing watchdog. A bounded 24 GiB product/mean/native probe is consistent with the accepted 32 GiB reporting ceiling. The 96-grid or 513-direction reference can justify a separate probe up to that ceiling, but its estimated metric cache leaves limited room for the rest of the workload. Preserve cutoff failures as inconclusive and do not automatically enlarge the cap. Comparison-only jobs avoid this metric cache and should retain their lower measured limits. Splitting a numerical pair across individual processes additionally requires a reviewed offline one-axis comparison that preserves its initial-state and reference contract; the existing closure/activity comparator deliberately rejects different scientific representations.

The review used read-only source inspection and Python's standard-library CSV/JSON parsing. The recorded focused disk-window test passed; its original combined invocation subsequently failed Code Analyzer, which is a separate gate. The coordinator's later `time-v2` invocation supplies the corrected Analyzer result. No MATLAB execution was initiated by this audit, and queued refinements are not assigned outcomes here.

## Follow-up review: lower product sampling

`windows/product` completes the fixed-space 769/1537/3074-point comparison, run `d19de4278652ec8e76dea8c7a531d19e2319fd8ce516c68648dc338b1cb8900c`. This is the same six-hour, 0.1 m/s, M100 peak-source stress fixture with no optional damping. All cases retain 64×64×385 samples, 257 thermal directions, four mean modes, the physical laws, 2057-point assembly, 900 s steps and the same nine observation times. Each completes 24 steps and 96 RHS evaluations with no rejections. The three surface-variance budgets remain inconclusive at this observation cadence; the other nine inventory budgets pass.

The passing preparation/trajectory path enforces exact equality of all authoritative scientific arrays except `nonlinearQuadratureCount`, `nonlinearQuadratureResidual` and `nonlinearReferenceResidual`. The factory separately requires the full polynomial-moment quadrature qualification at the declared count and two finer rules. The first case is normalized once on the common 513-point physical rule; subsequent cases use its authoritative physical state and the existing transfer without renormalization. Their canonical initial arrays need not be bitwise identical: the transfer introduces roundoff, measured by 36 passing source/pair preflight rows. The largest initial error consumes `1.19423e-7` of the already tightened initial allowance.

All 81 trajectory rows pass. The maximum error/effective-allowance ratio is `1.19423e-7`; the maximum 1537-versus-3074 reference error consumes `1.32475e-12` of that allowance. Maximum comparison and reference quadrature-uncertainty fractions are `1.54576e-14` and `3.37641e-15`. These tiny differences support the lower product rule on this fixed representation and window. They do not remove the fixture's displacement applicability flag or demonstrate occupied high-mode nonlinear flow. The input `scientificCacheHash` in the run contract is the empty-struct hash for the freshly constructed 769/3074 cases; actual scientific identities reside in their case manifests. It must not be reported as their constructed-array hash.

A conditional pilot recommendation can use 769 points with **no optional damping**, subject to a bounded remaining check set:

1. Measure matched 769-point M10 and M100 complete workloads under new case identities, retaining their distinct amplitudes and regimes. The existing aggregate case timings include different construction/restoration costs and are not a warm-throughput comparison.
2. Exercise one short actual-grid 769-point, no-optional-damping checkpoint/restore/continuation with scientific construction unavailable. This verifies the changed persisted product count and rebuilt nonlinear maps. The existing 1537-point horizontal-closure restart remains useful shared-interface evidence, but it is not that exact execution configuration. Reuse its unchanged observer/staged-tail tests rather than repeating the entire lifecycle matrix.
3. Include a dense-observation process-budget check for the selected pilot state, preferably in the same bounded lifecycle window. If the surface budget remains unresolved, make the denser check an explicit pilot prerequisite or stopping condition; a passing field comparison alone does not settle it.

Keep the completed 1537-point time/spatial qualifications identified as 1537-point evidence. This matched fixed-grid comparison supplies the narrow bridge to the 769-point candidate; it does not qualify 769 points at a different thermal count, arbitrary future high-mode states or another closure. No wholesale repetition of unaffected shared tests or spatial axes is required for this conditional recommendation. A mature seasonal campaign, acceptable production cost and the unmeasured applicability regimes remain separate prerequisites.
