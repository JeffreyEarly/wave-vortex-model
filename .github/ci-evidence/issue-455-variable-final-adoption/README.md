# Qualified v4 variable-transform adoption

The compact split pipeline passes every declared production and prior-pruned direct-flux gate and every compact complete-model gate for Stratified QG, Hydrostatic and exact-group Boussinesq. The [measurement decision](decision.json) is the unmodified final evaluator output. Its `defaultAdoption: false` distinguishes measurement evidence from the subsequent build/default/CI handoff; native default selection is recorded in `PortableRuntime/source-selection.json` and the final verification ledger.

The independent frozen source is `b157988355d2fabb6cbc62d56de18b203456897f`; the measured candidate is `a3acbf4dc9305c4d656399e9f98bc8360ddfa66f`. Sources, worker binaries, fixtures, driver/comparator and FFTW libraries remained unchanged within every final campaign. The only subsequent numerical-header change is three explanatory comments, recorded by old/new SHA-256 in the source-selection manifest. MATLAB scientific code, saved coefficient/modal layouts and numerical tolerances are unchanged.

## Complete execution results

All 160 direct-flux processes passed independent MATLAB and frozen-output comparisons. Across SQG and Hydrostatic at 256×256×129 and 512×512×257, plus Boussinesq at 256×256×129, compact/production complete-flux time is **0.23373**, with paired bootstrap 95% interval **[0.22920, 0.23831]**. Complete-process peak RSS is **0.70449** of production. The prior-pruned comparison also passes, at **0.70607** time and **0.76936** RSS. [Direct measurements, comparator decisions and provenance](direct-flux/README.md).

All 120 complete-model processes passed. Each family uses 256×256×129, one fixed RK4 step/four RHS evaluations, a full-volume tracer, coefficient output and off-step dense velocity output. Hydrostatic and Boussinesq also advance two particles. SQG uses explicit horizontal-only tracer advection. Each family has two excluded warmup process blocks and eight measured blocks, with four execution policies rotated through each block. Full NetCDF graphs are compared against an independently integrated MATLAB record and the frozen model. There are 237 complete graph comparisons across the three campaigns.

| Model | Compact / frozen integration time | Compact / frozen total process time | Compact / frozen peak RSS |
| --- | ---: | ---: | ---: |
| SQG | 0.21248 | 0.31292 | 0.93589 |
| Hydrostatic | 0.14680 | 0.17971 | 0.86341 |
| Boussinesq | 0.12027 | 0.60849 | 0.76636 |
| Equal-profile geometric mean | 0.15538 | 0.32465 | 0.85237 |

Every model profile passes the 1.03 integration-time limit and both owned-capacity and peak-RSS no-growth requirements. Setup, integration, close and total lifetime are reported separately in [the phase receipt](model/phases.json). For Boussinesq, median inspection/output preparation/model construction remain about 7.9/7.8/18.0 seconds; integration falls from 26.88 to 3.25 seconds. Startup therefore limits the speedup of this deliberately short model run. The direct-flux control already uses Accelerate matrices; the complete-model control uses its historical scalar matrix default. These are distinct baselines.

## Selection and retained limitations

New eligible Apple-silicon native runner builds select Accelerate split matrices, direct family views, tile-16 pruned horizontal transforms and streamed nonlinear targets. Horizontal workers follow available performance cores up to twelve; pointwise workers use up to eight; FFTW internal workers and general vertical outer workers are one. The selected eight-worker pointwise policy follows the [bounded calibration](../issue-455-pointwise-calibration/README.md). Vendor-internal BLAS threading is opaque and process-wide BLAS settings are not changed. Portable kernel constructors retain their established defaults; C++ consumers can explicitly inject the qualified services. Existing CMake cache selections remain authoritative, and explicit parallel FFT requests retain their reported full-FFT/interleaved path.

The candidate-interleaved comparison is preserved even though compact peak RSS is 0.109% higher for SQG 256 and 0.043% higher for Hydrostatic 256. It fails that additional comparator's strict RSS check; the required production and prior-pruned gates pass. The earlier #463 QG-256 prior-pruned flux ratio of 1.0338 also remains a failed historical screen; the final combined compact ratio is 0.8065. No unfavorable sample was removed or tolerance relaxed.

Boussinesq 512 direct flux is excluded by local capacity: scientific grouped arrays alone require about 20.29 GiB before copies. Complete-model 512 workloads and long-duration stability are not qualified by these short 256 workloads. Small grids have correctness coverage only; no small-grid tuning or performance claim is introduced. The public MATLAB compiled preview still does not expose variable-transform service injection; author parity probes cover the three families without expanding that public API.

The first Boussinesq final attempt stopped after its first passing warmup block because the progress summarizer requested a median before any measured samples existed. Its receipts and payloads are retained and excluded from acceptance. Commit `f9c149ad` fixes that reporting error and adds four focused regressions; the complete `bouss256-final-v2` campaign supplies the decision. A clean-path MATLAB reproduction also identified the independent SQG `addTracer` vertical-advection bug, tracked in [#467](https://github.com/JeffreyEarly/wave-vortex-model/issues/467).

The model archive retains all text reports, work counters, comparisons, commands, fixture/source/build/provider identities and the interrupted attempt. Its index verifies each member and references the complete local NetCDF payloads; those large binary scientific files are not repository products. First final outputs and the interrupted first outputs remain available locally. Later successful outputs were hashed and deleted only after full comparisons under the prospective retention protocol. No compression campaign was needed because the declared capacity guards passed with raw first outputs retained.
