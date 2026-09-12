# Shared Hydrostatic and Boussinesq field/gradient pipeline

User-authorized implementation, following the retained post-speed/phase EddyTide profile. No tracer optimization or MATLAB scientific change. The user permits relaxing or removing low-memory behavior where it would complicate this pipeline. Keep one shared algorithm; the existing physical-field low-memory setting need not be removed merely to permit retained spectral intermediates.

## Hypothesis and design

Factor field reconstruction into modal coefficient assembly, vertical reconstruction to a compact horizontal spectrum, and inverse FFT/derivative consumption. Cache the first two producers by explicit evaluation, registered view generation, normalized field and requested component. Four prognostic entries are preallocated; additional diagnostic/component entries are acquired lazily from a finite bounded catalog. Retain prepared capacity but clear all validity at event teardown. Remove/re-register invalidates the old view generation. Standalone operations clear their operation-local cache. Derived coefficient tendencies bypass the primary-state cache. Publish each intermediate only on successful production.

Hydrostatic reuses base modal coefficients for its complementary-basis vertical derivatives. Boussinesq applies the exact stored v4 D_F/D_G vertical operator to the shared horizontal spectrum before inverse FFT. These real operators are independent of horizontal mode and commute with horizontal synthesis. General full-grid calculus and tracers are unchanged. The initial physical-value reuse prototype was superseded after the observer-free Boussinesq profile attributed 40.5% of main-thread samples to prognostic vertical calculus. Horizontal derivatives multiply the shared post-matrix spectrum by ik/il into disposable scratch, preserving the source spectrum. This reassociation changes rounding and requires existing-tolerance parity and adaptive integration qualification. Keep a C++ execution switch to run the independent reconstruction oracle.

The native default and low-memory physical-field policies both use this pipeline. No duplicated low-memory derivative implementation, cache across completed evaluations, inferred same-time identity, or new FFT/matrix algorithm. Additional memory is measured and reported; the former 3% low-memory growth target is not a constraint for this user-authorized increment.

## Ownership and verification

Coordinator owns common cache/lifecycle design, Hydrostatic implementation, metrics integration, builds and timings. One Sol agent reviews lifecycle and later tests; another discovers Boussinesq fixtures/history and then owns Boussinesq family code. No concurrent benchmark/build workloads.

Before final source freeze: focused kernel/runtime tests across both representations and one/multiple workers, independent-vs-shared parity, component/view invalidation, state mutation across evaluations, failure publication, direct APIs, density aliases, producer elimination and allocated capacity. Early GCC and targeted MATLAB parity. Then one combined native/sanitizer suite, source-linked integration refresh and frozen paired qualification including EddyTide and representative Hydrostatic/Boussinesq fixtures. Do not infer a Boussinesq speedup from Hydrostatic sampling. Screen first; investigate complete-workload regressions above 3% without weakening scientific tolerances.

## Ledger

- Prerequisite PR #474 remains under required CI at branch creation; working source includes its qualified frozen implementation. Final integration must include its qualified merge result.
- Read shared/repo AGENTS, optimization workflow, caching, package design/release guides. No package metadata or snapshots change.
- Read-only design review and benchmark/history discovery dispatched; no redundant workers or builds.

- Early native shared-cache/Hydro/Bouss tests passed; both families match their independent reconstruction oracle across layouts, workers, components and derivatives. Added final actual-operator count assertions afterward; included in final suite.
- Early GCC build succeeded; focused native GCC tests scheduled. MATLAB parity running across both MM families/providers.
- Hydro three-pair screen: geometric integration ratio 0.87117 versus PR474; all output comparisons and state decisions passed; extra owned peak 33,678,880 bytes.
- Bouss original composite source is present. Prepared a source copy excluding dense/particle/tracer groups, retaining every scientific variable; archive holds derivation hashes. First profile attempt failed before execution (wrapper/method spelling); next sample measured startup and is excluded; corrected delay yielded steady integration sample. Retain all attempts.
- Final performance campaign will qualify reuse (two warmups/eight pairs), with separate low-memory correctness smoke. The shared kernel algorithm is identical under both policies; do not spend a full third set of expensive Boussinesq startups timing an optional physical-storage policy. Driver keeps its previous default of qualifying both policies, with explicit options to select reuse and record a memory budget.
