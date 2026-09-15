# Retained T10 workload, construction and diagnostic measurements

This page summarizes completed datasets regenerated after the Mac restart, including subsequent cold-start and product-sampling workload measurements. It reports their measured scope; the [main report](README.md) owns the overall qualification decision and window comparisons. The original `/private/tmp/t10-readiness` evidence was lost. Every number below comes from retained post-restart evidence under `/Users/jearly/Documents/OceanKitRepositories/thermal-readiness-t10-evidence`.

The [copied-file ledger](measurements/source-files.csv) records source-relative paths, byte counts and SHA-256 hashes for the small CSV/JSON evidence retained here. [Retained bootstrap scripts](measurements/reproduction-scripts.json) are preserved as text, including their original paths and collection hashes; command invocations and the limits of historical source-byte verification are described in [Reproduction.md](Reproduction.md). MAT caches, profiles and NetCDF trajectories remain outside git. The reported dataset directories were present.

## Workload scope and observed throughput

The host is the selected Apple M5 Max Mac with 48 GiB RAM and MATLAB R2026a Update 4 (`26.1.0.3312084`, `MACA64`). Each sample advances 21,600 model seconds with nonadaptive exponential stepping, a 900-second maximum/initial step, and four MATLAB threads. Each completes 24 accepted steps, zero rejected steps, 96 explicit RHS evaluations and zero extra output RHS evaluations. Output samples store coefficients every 10,800 seconds and four scalar inventories every 5,400 seconds, including time-zero records. These aligned sample cadences differ from the proposed production cadences.

The initial two thermal workloads use 64×64×385, 257 complete thermal directions, four mean modes, 2,057 assembly points and 1,537 product points. Both include nonlinear advection, physical diffusion, strict seasonal surface-displacement forcing and quadratic bottom drag. `workload10` starts from a **manufactured 0.01 m/s RMS pressure state**, at peak M10 source, with no optional damping. `workload100-horizontal` starts from the corresponding **0.1 m/s manufactured numerical stress state**, at peak M100 source, with the frozen horizontal-only closure. These are not cold starts or dynamically developed seasonal states; the stress state's physical applicability requires separate assessment.

The historical `pinned-apv-cold-v2` run starts from the **1 cm RMS surface-anomaly cold seed**, with zero initial QGPV, bottom anomaly and mean. It uses 64×64×513, 217 APV modes and 321 mean modes, WVM `4ec07256476ee57ceee23d70422baec65d1f31a4`, and InternalModes beta.4. Its four physical processes match the no-optional-damping specification, but its initial state differs from both thermal workload samples. Consequently, these rows do **not** establish a matched thermal/APV speedup or equal discretization accuracy. Its [contract](measurements/pinned-apv-cold-v2/pinned-contract.json) and [resolved dependency paths](measurements/pinned-apv-cold-v2/resolved-paths.json) preserve that distinction.

| Workload | Output | Repeats | Integration wall-time range (s) | Median model seconds per wall second |
| --- | --- | ---: | ---: | ---: |
| Manufactured M10, no optional damping | No | 3 | 11.7172–12.3404 | 1,835.15 |
| Manufactured M10, no optional damping | Yes | 3 | 11.8406–12.5688 | 1,780.32 |
| Manufactured M100 stress, horizontal-only damping | No | 3 | 11.8291–12.4964 | 1,806.09 |
| Manufactured M100 stress, horizontal-only damping | Yes | 3 | 12.2324–12.9107 | 1,724.90 |
| Historical APV cold M10, no optional damping | No | 2 | 5.02734–5.29906 | 4,186.35 |
| Historical APV cold M10, no optional damping | Yes | 2 | 5.33286–5.50170 | 3,988.21 |

Integration wall times include output closing but exclude initial output setup, scientific construction and integrator setup. The complete rows, including CFL and damping numbers, are in the [M10](measurements/workload10/integration.csv), [M100](measurements/workload100-horizontal/integration.csv) and [historical APV](measurements/pinned-apv-cold-v2/integration.csv) ledgers. Maximum recorded CFL is respectively `0.00483329`, `0.0483336` and `7.47112e-6`; the M100 horizontal-closure damping number is `0.0325101`. Small CFL and zero rejections describe these samples, not long-term stability.

The M10 1/2/4-thread screen measured median warm-RHS times of **0.248574 / 0.165138 / 0.118112 seconds**; four threads were selected. M100 reused four threads rather than repeating the screen. Thermal canonical restoration/integrator setup/first RHS cost **0.324634 / 18.1596 / 0.198223 seconds** for M10 and **3.40685 / 17.9710 / 0.208331 seconds** for M100 with closure. Initial output setup ranges were **0.275034–4.40354** and **0.294773–4.52823 seconds**, respectively. The historical APV factory took **118.292677 seconds**, followed by **7.098455 seconds** of integrator setup and **0.070090 seconds** for its first RHS. These phases are recorded separately in the [thermal M10 setup](measurements/workload10/setup.csv), [thermal M100 setup](measurements/workload100-horizontal/setup.csv) and [APV setup](measurements/pinned-apv-cold-v2/setup.csv) tables.

### Matched cold control and the 769-point candidate

`workload-cold10` and `workload-cold10-product769` supply thermal counterparts to the historical APV cold state: the same deterministic 1 cm surface seed, zero initial QGPV/bottom/mean, phase-zero M10 source, physical processes, four threads, fixed 900-second step and six-hour sample/output schedules, with no optional damping. Each set completes two samples per output policy, with 24 accepted steps, zero rejections and 96 RHS evaluations per sample.

| Matched cold M10 configuration | No-output wall-time range / median (s) | With-output wall-time range / median (s) |
| --- | ---: | ---: |
| Thermal, original 1,537 product points | 11.85795–12.30149 / **12.07972** | 12.26387–12.67228 / **12.46808** |
| Thermal, candidate 769 product points | 7.41435–7.84203 / **7.62819** | 7.91913–8.35146 / **8.13529** |
| Historical APV, 217 APV + 321 mean modes | 5.02734–5.29906 / **5.16320** | 5.33286–5.50170 / **5.41728** |

The lower product rule reduces the thermal cold median integration time by **36.85% without output** and **34.75% with output**. Its integration still takes **1.477× / 1.502×** the respective historical APV median wall time. These ratios compare matched input physics at different discretizations; they do not establish equal trajectory accuracy, confidence intervals from two samples, or mature-flow cost. Construction/setup costs remain separate. See the [original thermal](measurements/workload-cold10/integration.csv), [candidate thermal](measurements/workload-cold10-product769/integration.csv) and [APV](measurements/pinned-apv-cold-v2/integration.csv) timing ledgers.

The 769-point cold run's canonical restoration/integrator setup/first RHS cost **0.282886 / 17.997213 / 0.135622 seconds**. Its [guard](measurements/recovery/workload-cold10-product769/result.json) records **15,718,253,776 bytes (14.6388 GiB)** peak sampled footprint. Completed sample files remain **696,173,992–696,174,393 bytes**, with the same coefficient payload as the original thermal configuration: lowering product quadrature does not reduce its stored canonical scientific arrays. [Setup](measurements/workload-cold10-product769/setup.csv) and [I/O](measurements/workload-cold10-product769/io.csv) tables preserve these observations.

The candidate's additional M10 and M100 workloads both use **769 product points and no optional damping**, retaining their distinct manufactured amplitudes of 0.01 and 0.1 m/s at peak source. Each completes three repeats per output policy with the same 24 accepted steps, zero rejections, 96 RHS evaluations and zero extra output RHS evaluations per sample.

| Candidate manufactured workload | Output | Wall-time range / median (s) | Median model seconds per wall second |
| --- | --- | ---: | ---: |
| M10, 0.01 m/s | No | 7.30579–7.82533 / **7.39071** | 2,922.59 |
| M10, 0.01 m/s | Yes | 7.88335–8.31692 / **7.93014** | 2,723.79 |
| M100 stress, 0.1 m/s | No | 7.33604–7.87826 / **7.38395** | 2,925.26 |
| M100 stress, 0.1 m/s | Yes | 7.88599–8.32580 / **7.93402** | 2,722.45 |

The [M10](measurements/workload10-product769/integration.csv) and [M100](measurements/workload100-product769/integration.csv) tables record maximum CFL `0.00483329` and `0.0483336`, respectively, with zero optional damping number. Peak sampled footprints are **15,711,995,040** and **15,707,129,064 bytes**, from their [M10](measurements/recovery/workload10-product769/result.json) and [M100](measurements/recovery/workload100-product769/result.json) guards. Both retain the same **696,173,992–696,174,393-byte** completed sample-file range and **2,944,232-byte** coefficient payload. The original 1,537-point M100 workload used horizontal-only damping, so comparing it with this row changes closure as well as product sampling. None of these manufactured samples establishes mature M100 throughput or physical applicability.

## Output size and memory observations

| Workload | Initial output file, including first records (bytes) | Completed sample file (bytes) | Shape-derived coefficient-record payload (bytes) |
| --- | ---: | ---: | ---: |
| Thermal M10 | 690,283,168–690,283,569 | 696,173,992–696,174,393 | 2,944,232 |
| Thermal M100 with horizontal closure | 690,299,769–690,301,538 | 696,190,593–696,192,362 | 2,944,232 |
| Historical APV cold M10 | 23,896,587 | 28,921,522 | 2,511,440 |

Each scalar-record logical payload is 40 bytes. The measured subsequent growth is 5,890,824 bytes per thermal sample and 5,024,935 bytes per APV sample. File growth combines two coefficient records, four scalar records and format overhead; it does not independently measure allocated bytes per record type. Thermal file-restoration times are **0.377353–0.786616 seconds** for M10 and **3.39940–3.87711 seconds** for M100 with closure. These timings differ from the earlier in-memory canonical restoration. The [M10](measurements/workload10/io.csv), [M100](measurements/workload100-horizontal/io.csv) and [APV](measurements/pinned-apv-cold-v2/io.csv) ledgers retain the exact sizes and distinctions. Production checkpoint copies, temporary analysis storage and total allocated campaign storage are not measured by these samples.

The external guard sampled owned-process-family physical footprint every 0.25 seconds. Peak sampled footprints were **15,864,431,968 bytes (14.7749 GiB)** for [M10](measurements/recovery/workload10/result.json), **15,965,832,640 bytes (14.8693 GiB)** for [M100](measurements/recovery/workload100/result.json), and **5,683,190,144 bytes (5.29288 GiB)** for the [historical APV control](measurements/recovery/pinned-apv-v2/result.json). All completed beneath their operational 16 GiB cutoffs. These are sampled family footprints, potentially counting shared pages more than once; they are neither exact instantaneous peaks nor MATLAB array-allocation totals. OS child maximum-RSS accounting is preserved separately in the JSON records. A completed sample does not establish memory capacity for larger refinements or several simultaneous models.

## Conditional campaign arithmetic

The [candidate resource contract](measurements/resources-product769/resource-contract.json) scales only the completed 769-point workloads. M10 ranges pool its two cold and three manufactured samples per output policy; M100 uses its three manufactured stress samples. Each multiplier retains its own range. The combined row adds independent M10 and M100 campaigns executed serially. These are arithmetic extrapolations of six-hour controls, not measured annual runs, confidence intervals or mature-flow predictions.

| Model years per case | Case | Integration hours from no-output samples | Integration hours from sample-output runs |
| ---: | --- | ---: | ---: |
| 1 | M10 | 2.965–3.183 | 3.199–3.389 |
| 1 | M100 | 2.977–3.197 | 3.200–3.379 |
| 1 | M10+M100 | 5.942–6.380 | 6.400–6.768 |
| 5 | M10 | 14.825–15.913 | 15.997–16.947 |
| 5 | M100 | 14.886–15.986 | 16.002–16.894 |
| 5 | M10+M100 | 29.711–31.899 | 31.999–33.841 |
| 20 | M10 | 59.299–63.651 | 63.986–67.786 |
| 20 | M100 | 59.544–63.945 | 64.008–67.578 |
| 20 | M10+M100 | 118.843–127.596 | 127.994–135.364 |

The [full scenarios](measurements/resources-product769/scenarios.csv) add the measured startup subset once per independent campaign: canonical restoration, integrator setup, first RHS and, for output runs, sample output setup. That subset is **18.684–22.832 seconds for M10**, **18.700–22.721 seconds for M100**, and **37.383–45.553 seconds combined** with output, independent of campaign length. Those four phases are measured, but their sum excludes scientific construction, separate file restoration, extra checkpoints and offline analysis. The [component ledger](measurements/resources-product769/components.csv) preserves those distinctions. Integrator setup is not multiplied by the number of six-hour samples or output records.

Planned coefficient/scalar cadences are **T/48 = 657,450 seconds** and **T/384 = 82,181.25 seconds**, where T is 365.25 days. Counts include each file's time-zero record. The payload scenario adds subsequent shape-derived record payloads to the measured initial file; its format is unchanged by whether the throughput range used output samples. The measured sample-output cadence does not qualify wall cost at these production cadences.

| Years per case | Coefficient / scalar records per case | Initial file plus logical subsequent payload per case (GB) | Combined two-file payload scenario (GB) |
| ---: | ---: | ---: | ---: |
| 1 | 49 / 385 | 0.831621664–0.831622065 | 1.663243328–1.663244130 |
| 5 | 241 / 1921 | 1.396975648–1.396976049 | 2.793951296–2.793952098 |
| 20 | 961 / 7681 | 3.517053088–3.517053489 | 7.034106176–7.034106978 |

GB here means 10⁹ bytes. The combined scenario also doubles each record count, including two independent time-zero records. **Allocated future storage, extra checkpoint count/cadence/copies, coefficient-analysis wall cost and full campaign totals remain NaN**, as do production wall/disk acceptance limits. Do not interpret logical payload arithmetic as measured NetCDF allocation or add unknown costs as zero. The retained [original 1537-point scenarios](measurements/resources/scenarios.csv) remain separate; their M100 workload uses horizontal-only damping and must not be folded into the no-optional-damping candidate range.

## Warm nonlinear attribution

Five direct nonlinear evaluations of the manufactured M10 state gave median times of **0.0570472 seconds for reconstruction**, **0.0149671 seconds for products**, and **0.0299270 seconds for projection**. The kernel reported 162 radius groups and a **497,605,040-byte scratch estimate**, which is an analytic estimate rather than measured allocation. The separate instrumented warm-RHS profile attributed the largest project self times to `thermalNonlinearKernel` (0.0434236 seconds), inverse Fourier transforms (0.0416175 seconds across ten calls), and `projectThermalWeak` (0.0156665 seconds). Profiling overhead and nested timings preclude treating these as independent additive workload fractions. See [component timings](measurements/profile64/nonlinear-components.csv) and [profile self times](measurements/profile64/topProjectBySelfTime.csv). This profile does not separately qualify scalar propagation, offline analysis or campaign-wide I/O costs.

## Construction and diagnostic evidence

The retained baseline construction measurement is **33.653108875 seconds** for `thermalReadinessCase`, including manufactured-state initialization and writing `scientific64.mat`, at 1,537 product points. It is not pure eigensolver time or a separately measured 769-point factory cost. The [construction metadata](measurements/metadata-v2/construction64.json) records the case identity and configuration; later compatible cases restore the authoritative arrays. Resource scenario construction columns remain NaN because their workload CSVs measure restoration, while this separately identified construction result is known. Add the appropriate preparation path once rather than combining construction and restoration automatically.

The first metadata export [failed](measurements/recovery/metadata/result.json) because it requested the wrong timing variable and tried to JSON-encode complex manifest data. The corrected [metadata-v2 export](measurements/recovery/metadata-v2/result.json) completes in **26.323812 seconds** and exports complex manifest components explicitly. Original MAT files remain authoritative. The first zero-byte `metadata/construction64.json` remains a failed artifact indexed externally; it is omitted from small JSON copies because it is not a valid result.

All **1,094** requested radius pages passed the construction audit: 48, 162 and 337 radii at each of 32, 64 and 96 horizontal points, each evaluated with 257 and 385 thermal directions. The maximum eigenbasis condition is **21.3639699**, inverse residual **1.45487e-13**, eigen residual **2.16835e-16**, and endpoint-source residual **1.50427e-11**. The largest positive unit-diffusivity rate, **1.43154e-12**, is retained without clipping. At the previously failing radius, the balanced 2,057-point propagator error is **4.27775e251**, while the corrected unbalanced eigensolve gives **7.03254e-14** against direct matrix exponentiation. Homogeneous and both endpoint-source checks pass; dimensional near-zero responses remain visible in the [assembly-refinement ledger](measurements/construction-audit/assembly-refinement.csv). The [page ledger](measurements/construction-audit/radius-pages.csv) and [response ledger](measurements/construction-audit/response.csv) support construction behavior, not nonlinear spatial convergence.

The actual-64-grid diagnostic selected **64 APV modes on 129 stored diagnostic depths**, checked against the same band on 257 depths. Both active endpoint responses were checked at all 162 radii. Maximum mode-shape change was **1.70128e-8**; the 129-depth selected Gram error was **1.31047e-6**, and endpoint-grid error **4.23342e-10**. Basis construction took **4.42286 seconds** at 129 depths and **14.67371 seconds** at 257 depths. Physical integration used 513 points and a 1,026-point refinement; these quadrature nodes are distinct from stored output depths. [Capacity](measurements/diagnostic64-initial/capacity.csv) and [mode-comparison](measurements/diagnostic64-initial/mode-comparisons.csv) tables contain the checks and basis hashes.

Only one manufactured M10 record, labeled `capacity-only`, is present, with nonzero mean. Its coefficient change was **2.08572e-14** under quadrature refinement and **2.22011e-12** under stored-grid refinement. At the candidate diagnostic sampling, relative projection residuals were **2.28418% for QGPV**, **0.00517870% for velocity**, **0.0461799% for buoyancy**, and **0.143226% for the physical energy norm**. These are diagnostic representation residuals, not thermal trajectory errors. Component cross terms remain essential: total energy **2.46828** includes APV **413.612**, zero-APV **429.309**, and APV/zero-APV cross contribution **−840.932**, plus the recorded mean/residual terms. See [comparisons](measurements/diagnostic64-initial/comparisons.csv), [observables](measurements/diagnostic64-initial/observables.csv) and [inventories](measurements/diagnostic64-initial/inventories.csv).

The initial [diagnostic coverage ledger](measurements/diagnostic64-initial/regimes.csv) contains no cold, developed-zero-source or developed-peak-source records for either multiplier; no M100 nonzero-mean record is present. That historical subset remains conditional. The later required [13-record assessment](measurements/diagnostic64-regimes/summary.csv) is **FAIL**: both exact cold initial records fail the locked coefficient-relative sampling rule, while the other 11 records pass. These later records include cold M10/M100 startup and one-day endpoints, manufactured peak/zero-source controls and a provider-free restored checkpoint. The descriptive `developed-*` labels in the [record ledger](measurements/diagnostic64-regimes/records.csv) refer to manufactured controls; they do not establish mature seasonal coverage.

For `cold10-observation1` and `cold100-observation1`, relative APV coefficient changes are **53.450816%** under quadrature refinement and **56.543658%** under grid refinement, exceeding the fixed 1% limit. The [comparison function](../../../tools/compareThermalReadinessDiagnostics.m) divides the coefficient difference by the reference coefficient norm without a near-zero floor. The nominally zero initial QGPV therefore exposes relative sensitivity at roundoff scale: its physical source norm is about **1.84e-21 s⁻¹**, below the physical observable floor of **1e-13 s⁻¹**. All **36 physical observable comparisons** for these two records pass, with maximum residual change over source **2.27785e-7**. That physical stability does not override the failed coefficient criterion. Preserve the [failed rows](measurements/diagnostic64-regimes/comparisons.csv) and [physical comparisons](measurements/diagnostic64-regimes/observables.csv); a justified near-zero coefficient criterion and focused checks are separate follow-up work. The attempted 513-depth diagnostic fallback basis is absent at `diagnostic-bases64/apv-64e821e45770e9b0-Nz513-count64.nc`, and construction was disabled, as the [capacity ledger](measurements/diagnostic64-regimes/capacity.csv) records.

The separate **769-product-point restored checkpoint** passes its diagnostic comparison at time 1,923 seconds: coefficient changes are **2.09351e-14** for quadrature refinement and **2.22040e-12** for grid refinement. Its [one-record summary](measurements/diagnostic64-product769-restored/summary.csv) remains **CONDITIONAL** for coverage. This successful provider-free record does not repair the required 13-record failure.

The cold M10 budget observation refinement also stopped at its **16 GiB operational cutoff**, after **197.962149 seconds**, with **17,179,937,128 bytes** peak sampled footprint. The retained [contract](measurements/windows-budget-refined/cold10/run-contract.json) requests 128 unique observation times for the original 1,537-product-point one-day cold case, and all 128 observation rows were written; the subsequent budget assessment did not complete. Its [guard result](measurements/recovery/budget-cold10/result.json) is a memory cutoff, not a completed refined budget or permission to raise the cap. Required diagnostic acceptance, this unresolved cold budget and the missing finer thermal trajectory leave seasonal-campaign readiness unestablished; the [main report](README.md) records **NOT READY**. No workload dataset covers a complete forcing cycle or mature-flow throughput.

## Sampled physical applicability

The [63-record metadata ledger](measurements/metadata-v2/sampled-regimes.csv) evaluates nine saved states in each of seven original 1,537-point windows. The table reports maxima over those saved records, not continuous-time extrema or additional trajectory runs. The displacement columns retain the transform's `eta` and `eta_i` definitions.

| Retained windows | Duration | Maximum eta/depth / eta_i/depth | Maximum relative vorticity/f | Maximum surface slope | Order-one flags / records |
| --- | --- | ---: | ---: | ---: | ---: |
| Cold M10 | One day | 5.42630e-6 / 5.43393e-6 | 2.60406e-5 | 4.05673e-10 | 0 / 9 |
| Cold M100 | One day | 6.68176e-6 / 6.68978e-6 | 5.75796e-5 | 5.56474e-10 | 0 / 9 |
| Manufactured M10, peak source | Six hours | 0.133339 / 0.133339 | 0.0171865 | 2.53698e-7 | 0 / 9 |
| Manufactured M10, zero source | Six hours | 0.133339 / 0.133339 | 0.0171865 | 2.53260e-7 | 0 / 9 |
| Manufactured M100 stress: closure-control, zero-source and activity windows | Six hours each | 1.31822 / 1.31822 | 0.171865 | 2.53702e-6 | 27 / 27 |

The flag is triggered when any of these sampled dimensionless indicators reaches one. It remains clear that the cold controls are small-amplitude over one day, while the manufactured M100 pressure fixture has order-one displacement throughout the saved windows. Absence of a flag is not a full asymptotic validity qualification; the short cold samples do not establish mature M100 behavior. These indicators do not change the failed diagnostic rule or incomplete reference/budget gates.

## Retained failed historical attempt

The first post-restart historical baseline attempt failed before integration because the authoring harness called an unavailable endpoint reconstruction interface. Its [failure summary](measurements/pinned-apv-cold/pinned-summary.json) is retained. The revised run uses the public reconstruction path and completes all four requested samples; the failed attempt contributes no timing samples to the successful control.
