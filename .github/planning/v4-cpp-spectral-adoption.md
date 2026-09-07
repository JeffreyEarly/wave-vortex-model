# v4 C++ spectral adoption: focused audit and design

Status: proposed implementation design, based on completed source inspection and the verification ledger below. No production implementation or production-performance default changes in this audit.

## Decision

Keep v4's public coefficient representation, scientific authoring boundary, integration contracts, and restart format. Add prepared horizontal and vertical operator services beneath the existing kernels. Use the selected spectral-kernel-benchmarks algorithms as implementation evidence, while qualifying the complete WVM calculation separately.

The first functional extension is the persisted variable-stratification contract in [#295](https://github.com/JeffreyEarly/wave-vortex-model/issues/295), followed by Stratified QG, Hydrostatic, and Boussinesq. A bounded constant-stratification optimization supplies an independent proving ground for shared FFT and workspace machinery. Completion of every constant-stratification optimization is not a prerequisite to the modal-contract work.

## Baselines and scope

| Item | Audited identity |
| --- | --- |
| WVM | `da764d03404215be708c4bae3e8d046811773e06`, GitHub `main` verified on 2026-09-07; manifest 4.3.0 |
| Isolated branch | `audit/v4-cpp-spectral-adoption` |
| Benchmark publication | `6f2e4cd9e2f092433a584645e573d818ecaca42b` |
| Executed benchmark source in cross-machine synthesis | `3bb0959fc82fe2811ba1ccaedc1c49b1e4fd10a7`, clean source with implementation and fixture hashes |
| Historical constant-flux WVM oracle | `6ad254fb9756ac918bb72e036020d004879df1f2` |
| Scope inspected | Kernel descriptors, coefficient and FFT views, native provider, MEX capability checks, integration state, forcing/velocity reuse, checkpoint/model/field adapters, MATLAB modal operators, benchmark contracts and selected provider implementations |

`git diff 6ad254fb9756ac918bb72e036020d004879df1f2..da764d03404215be708c4bae3e8d046811773e06 -- CompiledKernel PortableRuntime` is empty. This establishes source continuity for those directories; it does not update the historical fixture identity or prove current MATLAB parity.

The sibling WVM authoring checkout is on `feature/v5.0-free-surface-qg`. It was not switched or edited. The benchmark checkout contains unrelated uncommitted handoff/site edits; conclusions here use its committed contracts and published JSON. No benchmark sources or released OceanKit snapshots were changed. This is a focused extension audit, not exhaustive numerical, concurrency, security, or all-platform qualification.

## Findings and required responses

### A1. Preserve canonical state; specialize only execution storage

**Confirmed contract.** [WVKernelTypes.hpp](../../CompiledKernel/include/WaveVortexKernel/WVKernelTypes.hpp) exposes interleaved `WVComplex64` arrays in column-major `[Nj,Nkl]`. [WVIntegrationState.hpp](../../PortableRuntime/include/WaveVortexRuntime/WVIntegrationState.hpp) generalizes coefficient-family counts and shapes, but its family views still point to `WVComplex64`. Barotropic QG already retains only its `A0` family.

The benchmark's 15 ready modal inputs are derived fields, not WVM's authoritative three coefficient arrays. Its compact-versus-native memory ratio cannot be applied directly to WVM state, RK stages, or total process memory.

**Decision.** Keep public state, RK stage storage, MEX inputs/outputs, and persisted coefficients interleaved in canonical WVM order. Prepare split internal field views where useful; fuse coefficient assembly into their final destinations and accumulate projected results directly into canonical flux views. Do not materialize 15 complete intermediate fields merely to match the benchmark entry point. Retain an interleaved direct-view implementation for matched comparison. A future split authoritative-state API would require a separate compatibility proposal and complete integration evidence.

### A2. The current FFT interface cannot describe the selected graph

**Confirmed gap.** [WVFFTEngine.hpp](../../CompiledKernel/include/WaveVortexKernel/WVFFTEngine.hpp) describes horizontal real 2-D transforms and vertical DCT-I/DST-I. It has no complex row/column transform kind, retained-mode operator, split-complex view, or stage-specific worker policy. General vertical matrix multiplication has no provider boundary.

**Decision.** Add a prepared retained-horizontal operator interface and a small vertical-matrix interface, rather than pretending a pruned retained operator is an ordinary full 2-D FFT. Leave `WVFFTEngine` and existing callers operational. Use a reference horizontal adapter over the existing engine and a native retained implementation that privately owns its separable FFTW plans. Keep FFTW and Accelerate headers out of `CompiledKernel/include` and `CompiledKernel/src`; retain C++17. The benchmark laboratory is C++20 and is not a production dependency.

### A3. Inverse preservation metadata is not enforced

**Reproduced provider-contract gap.** [WVNativeFFTWEngine.cpp](../../CompiledKernel/adapters/native-fftw/WVNativeFFTWEngine.cpp) ignores `WVFFTPlanSpecification::destroysInput`. The audit requested an out-of-place 8-by-6 c2r inverse with `destroysInput=false`. Plan creation and execution succeeded, the spectrum changed, and the normalized round trip remained correct to `3.33e-16`.

Existing constant-stratification inverse specifications explicitly set `destroysInput=true` and use scratch; this probe is not evidence of corrupted current caller coefficients. It is an adoption blocker for a new caller that relies on immutable direct views.

**Required response.** For each provider, enforce the declared placement and preservation contract at setup. Reject a preservation request the selected native plan cannot honor, or expose an explicitly accounted prepared-copy strategy. Never silently accept a stronger preservation promise. Keep immutable modal inputs distinct from disposable reconstructed spectra. Test direct input preservation as well as numerical output.

### A4. Warmed calls still allocate and create threads

**Reproduced adoption gap.** `forEachModeBlock` in [the constant kernel](../../CompiledKernel/src/WVTransformConstantStratificationKernel.cpp) creates a vector of transient threads on each coefficient stage. At `[16,12,9]`, `Nj=5`, `Nkl=36`, with one native FFTW worker and default coefficient workers, a warmed ordinary flux call made:

| Flux | C++ allocation calls | Requested bytes | Caller coefficients preserved |
| --- | ---: | ---: | --- |
| Hydrostatic | 28 | 672 | Yes |
| Nonhydrostatic | 36 | 864 | Yes |

These are intercepted `new`/`new[]` calls, including aligned variants. They exclude libc/FFTW allocations, thread stack allocation, and process RSS. They demonstrate a difference from the benchmark's zero warmed application-allocation target, not a violation of v4's weaker no-array-sized-allocation promise.

**Required response.** Prepare persistent worker executors before execution and join them during destruction. Preserve a serial implementation. Report coefficient, horizontal, vertical, and pointwise scheduling separately; do not create nested executing teams. Setup failure must leave no workers or plans running. The current boolean reentrancy guard is not a cross-thread mutex: retain single-active-call-per-workspace ownership and use separate workspaces for concurrent execution.

### A5. Preserve the current six-volume streaming improvement and RHS reuse

**Confirmed useful behavior.** The ordinary constant kernel has `4H+6R` scratch: four complex half-spectrum volumes and six real volumes. It retains three velocities, reconstructs a derivative triple, and overwrites the consumed x derivative with the target. The general benchmark uses a seven-real-volume lifetime. Porting its workspace literally would lose the existing six-volume optimization.

[WVForcingEngine.cpp](../../PortableRuntime/src/WVForcingEngine.cpp) can retain or consume external advection fields. [WVConstantStratificationIntegrationSystem.cpp](../../PortableRuntime/src/WVConstantStratificationIntegrationSystem.cpp) reuses them for particles and tracers and prepares scalar advection during construction when tracers require it. The scalar kernel API itself retains lazy preparation as a compatibility path.

**Required response.** Support optional caller-owned velocity output and immutable precomputed velocity input. Retain velocity validity only for the exact RHS occurrence/state; invalidate on a new state, stage, accepted-state constraint, or restored model. Reuse the six-volume lifetime where its aliasing proof applies. External velocity storage belongs in the caller's memory ledger; the current kernel still retains its internal arena when external velocities are supplied. Budget additional storage explicitly for variable-stratification displacement values and any projection intermediates; do not claim a universal six- or seven-volume bound without a complete lifetime table. Prepare every configured tracer/field plan before the allocation gate.

### A6. Hydrostatic matrices are simpler than the grouped benchmark, but the complete physics is broader

**Confirmed MATLAB structure.** [WVGeometryDoublyPeriodicStratified](../../@WVGeometryDoublyPeriodicStratified/WVGeometryDoublyPeriodicStratified.m) supplies `PF0inv`, `QG0inv`, `PF0`, `QG0`, `P0`, `Q0`, `h_0`, `z_int`, and `dLnN2`. Hydrostatic uses these horizontal-wavenumber-independent matrices, shares F/G reconstruction for wave and geostrophic contributions, and has an identity `transformWithG_wg`. Stratified QG uses the same base vertical structures with `A0` only.

[Boussinesq geometry](../../@WVGeometryDoublyPeriodicStratifiedBoussinesq/WVGeometryDoublyPeriodicStratifiedBoussinesq.m) additionally uses group-dependent `PFpmInv`, `QGpmInv`, `PFpm`, `QGpm`, `Ppm`, `Qpm`, `h_pm`, `QGwg`, and exact `K2unique`/`iK2unique` membership. Do not recompute that membership from integer radius or merge groups on approximate matrix equality.

The benchmark's wave-F/wave-G 15-to-4 boundary does not include the full wave/geostrophic/inertial/MDA construction and projection. [WVNonlinearAdvection](../../Forcing/WVNonlinearAdvection.m) also evaluates the displacement contribution `-w .* eta .* dLnN2`. Hydrostatic has three targets, Boussinesq four, and QG one PV target with horizontal advection. Boussinesq projection additionally needs its divergence/vertical-velocity operators.

**Required response.** Start with one shared vertical group for QG/Hydrostatic, while designing explicit group maps for Boussinesq. Build independent MATLAB fixtures for each full transform and RHS. Include nonzero stratification gradient and mean-density/inertial modes so omitted terms cannot pass through zero fixtures.

### A7. Runtime interfaces are reusable, but transform dispatch is still two-family

**Confirmed extension work.** `WVPersistedTransformKind` contains constant stratification and Barotropic QG. Checkpoint inspection rejects other transform identities before allocating state. Model, output, and field adapters frequently implement a QG branch followed by a constant-stratification path. Current preflight makes that valid; adding only an enum or kernel would not make these paths generic.

**Required response.** Add explicit dispatch for every supported kind, with rejection for unknown kinds, at checkpoint inspection/read/write, model construction, forcing resolution, field planning/evaluation, output reconstruction, compatibility comparison, and metrics. Reuse `WVIntegrationSystem`, the shared RK driver, output driver, and immutable extension catalog. Avoid a new universal transform class or transform branches inside the integrators. Extend the existing field-service adapters at field/event granularity, not per grid point.

### A8. Implementation metadata and failure ownership need coordinated updates

**Confirmed coupling.** The MATLAB compiled-backend check requires contract 4 and seventeen plans. `CompiledKernel/source-selection.json`, `TestCompiledKernelIntegration`, MEX reporting, and native self-tests encode plan/scratch/schedule choices. `FFTWPlan::persistentBytes()` counts its C++ wrapper, not opaque FFTW storage; the current reporting correctly treats plan accounting as a lower bound.

**Required response.** Give the new schedule an explicit identity and independently version its operator contract. Keep the legacy contract available during qualification; if replacing its encoded semantics, coordinate a kernel-contract version increment across producers, consumers, fixtures, and capability checks. This does not imply a new portable source-API major or a checkpoint-format change. Source API v1 remains compatible unless its documented surface actually changes incompatibly.

Retain lower-bound labels for opaque provider memory; report owned capacity, setup peak, and fresh-process RSS separately. Audit setup failure with injected failures at allocation/plan/worker stages. In particular, native planning currently acquires raw surrogate buffers before constructing the r2r-kind vector, and its wrapper-allocation failure path destroys the raw plan outside the planning mutex. These are static failure-path concerns, not reproduced leaks in this audit; use RAII and serialized native plan cleanup when extending this code.

## Proposed adoption architecture

### Ownership and construction

The following names describe proposed internal responsibilities, not frozen public C++ APIs.

| Object | Owns | Lifetime and dependencies |
| --- | --- | --- |
| Modal record | Canonical MATLAB-authored geometry, operator matrices, weights, preconditioners, mode/group identities | Validated, immutable scientific input; retained wherever needed for exact output/restart |
| Prepared modal operators | Provider-ready matrix layouts, exact group views, derivative/projection products | Immutable derived data; depends on the complete modal record and selected representation/provider |
| Prepared horizontal operator | Retained-mode maps, normalization policy, native plans and placement contract | Depends on dimensions, exact physical wavenumbers/domain, parity/mask rules, representation, provider and worker policy |
| Execution workspace | Phase buffers, streamed physical fields, split/interleaved transient arenas, worker executors | One active execution; sized once for configured operations; rebuilt after configuration/restart |
| Existing model/integration state | Canonical coefficients and observer state | Remains the sole authoritative evolving state |

Construct in this order: inspect identity and dimensions; stream-validate finite matrix payloads and relationships; validate all configured capabilities and destinations; load the authoritative records/state; prepare immutable operators; create plans/workspaces/workers; publish the completed model. Validate large payloads in bounded chunks before allocating derived execution storage. This is allocation-light preflight, not a promise that matrix validation can happen without reading matrix data.

A new grid, stratification, retained basis, normalization, or group map creates a new prepared context. Do not invalidate immutable geometry operators on ordinary time evolution. Do not serialize FFT wisdom, plans, split buffers, schedules of worker execution, pointers, or derived provider permutations. Preserve existing MATLAB persistence identities and exact source-linked extension contracts.

### Horizontal service

Provide forward physical-to-retained and inverse retained-to-physical operations on explicit interleaved or split views. A view carries extents, strides, family/channel identity, and constness; setup validates byte spans, checked products, provider integer limits, aliasing, and representation agreement. Dispatch is selected during setup and never inferred from a raw pointer.

The reference path executes the existing full transform plus explicit gather/embed. The native compact path ports the selected tile-16 partial-column pruning, contiguous reusable half-spectrum clear, and direct family views. The native interleaved path uses validated direct strided FFTW views. Keep normalization owned by WVM and apply it exactly once; never import the superseded synthetic benchmark's pointwise scaling into the physical flux.

The operator receives WVM's exact retained set. Do not hard-code square grids, one horizontal ordering, mandatory antialiasing, or the benchmark's default `Nj=floor(2*(Nz-1)/3)`. Preserve odd/even, nonsquare and unequal-domain geometries, DC/Nyquist/Hermitian rules, legal explicit truncation, and antialiasing on/off. A capability-selected full-transform path remains available where pruning has not been qualified; report it explicitly and do not silently change physics or fallback after an execution error. This is a correctness capability distinction, not size-dependent performance tuning.

### Vertical service and #295 record

Describe each real matrix by rows, columns, leading dimension, orientation, exact source identity and group membership. Support reconstruction `[Nz,Nj]`, projection `[Nj,Nz]`, and cross-family products `[Nj,Nj]`; accept explicit source/destination strides and accumulation semantics. Matrix shape and group membership are independent of whether the caller's values are split or interleaved complex.

Implement a small scalar reference multiply for correctness and non-Apple builds. The Accelerate adapter supports two real GEMMs on split real/imaginary values and the benchmark's direct complex GEMM path on interleaved views. Immutable matrix preparation occurs once. Deduplicate only by authoritative source identity; retain one shared F/G group for Hydrostatic and Stratified QG. Avoid expanding each matrix once per horizontal mode. Where exact group membership is discontiguous in canonical ordering, prepare segments and fuse assembly/projection around those views; any unavoidable gather/scatter belongs in measured execution and the memory ledger.

For #295, decode and compare the actual MATLAB schema, including base stratification and geometry required properties, vertical mode keys, `PF0inv/QG0inv/PF0/QG0`, `P0/Q0`, `h_0`, `z_int`, and `dLnN2`. Preserve coordinate orientation and boundary zeros, not just matrix extents. Validate mode subsets, finite values, nonzero required preconditioners and mathematically valid transform-specific scales; do not impose generic invertibility on intentionally truncated or zero-barotropic G operators. Add Boussinesq's wave families/group maps in its later record extension. No C++ eigenproblem solve is introduced.

### Full flux composition and worker policy

Keep three scientific compositions above these services: QG PV advection, Hydrostatic three-target flux, and Boussinesq four-target flux. Retain the analytic constant-stratification Type-I specialization. Fuse phase and coefficient assembly with final internal views, stream targets, and accumulate into the caller's canonical flux arrays. Include the displacement value needed by `dLnN2` explicitly in the derivative/lifetime design; it cannot be recovered by treating the benchmark's generic derivative triple as a complete WVM RHS.

Preserve ordinary, velocity-producing, and velocity-consuming call forms. Keep forcing order and amplitude constraints in the existing forcing engine, and particle/tracer reuse in the integration system. The first variable-stratification runtime milestone does not automatically expand the MATLAB compiled-preview selector; that exposure requires its own capability and forcing qualification.

Start from the benchmark's topology policy: horizontal outer workers equal performance cores; general vertical workers one; general FFTW internal workers one; requested Accelerate threads one under outer scheduling; constant Type-I internal workers equal total physical cores. Calibrate pointwise workers over the published bounded candidate set. Do not mutate process-wide BLAS environment variables from a MEX call; qualify an embedding-safe provider control or report the effective policy as unverified. Join stage work before entering the next internally threaded library. Revalidate policy with MATLAB loaded and with standalone runtime storage present. No broad resweep or machine-specific performance promise is part of this design.

## Numerical and performance acceptance

Separate three numerical comparisons. Existing passing test tolerances remain authoritative for their fixtures; do not loosen them to obtain adoption.

| Boundary | Required evidence |
| --- | --- |
| Primitive/general operator | Exact mode-keyed mappings and independent scalar/DFT oracle; the historical general benchmark uses maximum scale-normalized and relative L2 errors at most `1e-12` |
| Constant optimized schedule versus historical compiled/control oracle | Preserve the historical dual gate: maximum at most `2e-12`, relative L2 at most `1e-12` for the qualified large fixtures |
| Complete WVM MATLAB/C++ physics | Current small-fixture thresholds plus independent full-transform/RHS tests; the historical large constant fixture used a separate `1e-10` MATLAB/compiled cross-audit, not the tighter schedule-equivalence threshold |

Freeze variable-stratification tolerances against conditioning and independent MATLAB results before tuning. Do not claim every profile must satisfy one universal relative error, especially near-zero modes. Report both the maximum scale-normalized error and relative L2 with explicit normalization. Test nonzero reference-time phase, F/G endpoint behavior, wave/geostrophic/inertial/MDA modes, special horizontal modes, variable `Nz/Nj`, nonuniform vertical nodes, and multiple stratification profiles. Check modal round trips on representable subspaces, derivative identities, energy/invariants, full tendencies and linear frequencies.

The new execution gate requires input preservation, documented output aliasing, no new application allocations or thread creation after all configured operations are prepared, balanced plan/worker destruction, and bounded workspace independent of step count. Include rejected-step and restored-state reuse, scalar advection, field-only calls, and forced plan/allocation failures. Separate application allocation accounting from unavailable provider-internal accounting.

Performance adoption compares the integrated candidate with current `da764d0` on matched inputs and call boundaries. Record setup, kernel time, adapter/conversion time, complete RHS, integration, observer/output work, owned bytes and fresh-process peak RSS. Use the two calibration profiles plus small/odd/nonsquare functional profiles and representative coefficient-only and particle/tracer/dense-output workloads. Use fixed-step matched work to attribute RHS gains; validate adaptive scientific results and accepted/rejected work separately because roundoff can change step sequences.

For replacing the default constant schedule, propose the benchmark-style gate of at least 10% geometric complete-flux improvement, no declared timing profile above 1.03 times control, a paired interval excluding a tie, and no memory regression, with one policy across sizes. Freeze the production workload set and sampling protocol before measurement. If it fails, retain the existing schedule and continue the variable-stratification feature work. For a new transform, correctness/runtime qualification can ship before a claim of best performance; the faster internal representation remains an explicit measured selection.

The cross-machine synthesis reports compact-general speedups of 1.35 on M4 Max and 1.43 on M1 Max relative to its optimized native general boundary, with about 49% of native algorithm-resident memory at the larger calibration size. It explicitly sets `productionValidated=false`. Its 15 ready-input storage, grouped Boussinesq matrices, and seven-real-volume lifetime differ from complete Hydrostatic and current constant WVM. These ratios are motivation, not product acceptance results.

## Implementation sequence and reviewable slices

| Slice | Concrete result | Acceptance and dependencies |
| --- | --- | --- |
| 1. Ownership/provider hardening | Enforced inverse preservation, RAII plan cleanup, explicit single-workspace execution, persistent executor primitive | Preservation/failure/allocation tests; unchanged current numerical fixtures |
| 2. Operator contracts and reference implementations | Retained-horizontal service, vertical matrix views, scalar matrix reference, explicit setup identities | Odd/even/nonsquare and aliasing tests; no forbidden core dependencies; source API v1 clients still compile |
| 3. Native horizontal + bounded constant adoption | Tile-16 pruned FFTW, retained-row Type-I, fused canonical-to-internal assembly, truthful metrics/capabilities | Current MATLAB parity, all configured operation preparation, integrated constant performance gate; preserve velocity reuse |
| 4. #295 + Stratified QG #296–#298 | MATLAB modal record decoding, single-group vertical native provider, A0-only kernel and complete runtime adapters | Matrix/calculus/MATLAB comparisons, forcing compatibility slice, MATLAB → C++ → MATLAB continuation |
| 5. Hydrostatic #299–#301 | Shared-matrix Ap/Am/A0 kernel, complete stratification-gradient flux, fields/observers/restart | Multiple profiles, truncated modes, full physics and all supported integrator qualification; depends on #295 and #298 |
| 6. Boussinesq #302–#304 | Exact grouped wave matrices, wave/geostrophic conversion and vertical-velocity projection | Group identity, hydrostatic-limit, four-target flux and complete continuation qualification |

Slices 3 and 4 both consume slice 2; #295's schema/fixture work can start before native optimization. Existing forcing/closure parity (#290–#294) gates transform integration/qualification rather than the first standalone numerical kernel. Controlled termination (#288–#289) and standard diagnostics/catalog completion (#305–#307, #314–#315) remain part of the broader [#310 roadmap](https://github.com/JeffreyEarly/wave-vortex-model/issues/310).

Reuse milestones 17–19 for the transforms. A small additional milestone can track slices 1–3. Suggested issue titles are “Enforce spectral provider ownership and prepared execution”, “Add retained-horizontal and vertical-matrix operator contracts”, and “Qualify the selected constant-stratification spectral schedule”. Their scope and acceptance are the table above. No issues, comments, milestones, or PRs were created by this task.

## Source map for implementation

| Concern | Existing source to extend or preserve |
| --- | --- |
| Public views and existing descriptor | `CompiledKernel/include/WaveVortexKernel/WVKernelTypes.hpp` |
| FFT contract and providers | `CompiledKernel/include/WaveVortexKernel/WVFFTEngine.hpp`, `CompiledKernel/adapters/{reference,native-fftw}` |
| Constant fused schedule | `CompiledKernel/src/WVTransformConstantStratificationKernel.cpp`, `WVCoefficientFormulas.hpp` |
| State families and RK compatibility | `PortableRuntime/include/WaveVortexRuntime/WVIntegrationState.hpp`, `WVIntegrationContracts.hpp`, `WVRungeKutta.hpp` |
| RHS velocity reuse | `PortableRuntime/src/WVForcingEngine.cpp`, `WVConstantStratificationIntegrationSystem.cpp` |
| Transform integration | `PortableRuntime/src/WVModelTransformAdapters.*`, `WVCheckpointTransformAdapters.*`, `WVModelOutputTransformAdapters.*`, `WVOutputTransformAdapters.*`, `WVFieldEvaluationService.cpp` |
| Capability and adoption records | `CompiledKernel/source-selection.json`, MEX reports, `@WVCompiledConstantStratificationBackend`, `UnitTests/TestCompiledKernelIntegration.m`, `UnitTests/TestCompiledPreview.m` |
| Benchmark algorithms to port selectively | `src/pruned_fftw_provider.cpp`, `src/vertical_gemm.cpp`, `src/pointwise_advection.cpp`, `src/constant_stratification.cpp`, `src/authoritative_spectral_flux.cpp` in the pinned benchmark repository |

Benchmark references: [committed handoff](https://github.com/JeffreyEarly/spectral-kernel-benchmarks/blob/6f2e4cd9e2f092433a584645e573d818ecaca42b/docs/wvm-compiled-core-integration-handoff.md), [general fixture contract](https://github.com/JeffreyEarly/spectral-kernel-benchmarks/blob/6f2e4cd9e2f092433a584645e573d818ecaca42b/docs/wvm-spectral-flux-fixture-contract.md), [constant fixture contract](https://github.com/JeffreyEarly/spectral-kernel-benchmarks/blob/6f2e4cd9e2f092433a584645e573d818ecaca42b/docs/wvm-constant-stratification-flux-fixture-contract.md), [cross-machine synthesis](https://github.com/JeffreyEarly/spectral-kernel-benchmarks/blob/6f2e4cd9e2f092433a584645e573d818ecaca42b/results/published/decisions/issue-023-portable-machine-tuning-cross-machine-v1.json).

## Verification ledger

- Reused the preceding review's successful `WVKernelContract` and `WVBarotropicQGKernel` runs at the identical WVM commit; no production source has changed and the gates were not repeated.
- Compiled and ran [the native audit probe](v4-cpp-audit/probe.cpp) with C++17, AppleClang, warnings as errors, and the existing local FFTW 3.3.11 provider. Observations are recorded in A3/A4. All plans were destroyed and outstanding planning-surrogate bytes returned to zero.
- Built the current reference runtime and the four selected test executables with AppleClang 21/C++17 and warnings as errors in temporary storage. `checkpoint-reader`, `unified-integration`, `model-facade`, `field-evaluation`, `runtime-architecture-source-policy`, and `barotropic-qg-architecture-source-policy` all passed (6/6). Selection command: `ctest --test-dir <temporary-runtime-build> --output-on-failure -R '^(checkpoint-reader|unified-integration|field-evaluation|model-facade|runtime-architecture-source-policy|barotropic-qg-architecture-source-policy)$'`.
- Ran `buildtool docs:check` once successfully after `restoredefaultpath` and `configureCIEnvironment` with the listed OceanKit snapshots and exactly ClassDocumentation 1.3.2. It validated 2,026 files and 4,145 routes with zero failures and zero generated differences. The initial sandboxed MATLAB launch exited without output before the check started; the successful launch ran outside that sandbox. A final ledger/lifetime clarification changes only this planning document and cannot affect generated documentation, so the successful check was not repeated.
- Checked all local Markdown links, shell syntax, and whitespace including new untracked files. The only added files are this planning document and its two audit-probe sources. Package manifest, generated artifacts, website sources, production C++/MATLAB, and released snapshots remain unchanged. No MATLAB source or tests changed, so MATLAB Code Analyzer was not required.

Reproduce the probe from the repository root with `sh .github/planning/v4-cpp-audit/run-probe.sh <existing-FFTW-provider-root> <temporary-build-directory>`. It reports observations, not a production performance benchmark, and deliberately returns success when an observed preservation mismatch confirms the audited baseline behavior. Future regression tests must assert the new intended behavior independently.

No production benchmark campaign, new MATLAB full-flux comparison, sanitizer campaign, Linux run, release export, or external source-API consumer build was performed for this design. Those gates belong to the implementation slices. The native libraries were reused read-only from an existing local cache; the audited WVM sources were compiled in isolation.
