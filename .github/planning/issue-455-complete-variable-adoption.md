# Complete v4 variable-transform adoption

The active combined goal covers #455 and #463. Its integration baseline is v4 main `b157988355d2fabb6cbc62d56de18b203456897f`, which merged PR #464. MATLAB APIs, saved scientific records, canonical coefficient ordering and numerical tolerances remain unchanged. The separate v5 checkout is outside this work.

## Implementation sequence

1. Bound duplicate full-grid derivative preparation for pruned execution (#463). Preserve every resolved Fourier frequency, even-grid Nyquist derivative rules, scalar operations and event-owned fields. Compare with the existing pruned candidate as well as the frozen production schedule.
2. Adapt the frozen benchmark `compact-general-fused-views-v1` implementation to actual WVM coefficient construction and output projection. Integrate shared-matrix Stratified QG/Hydrostatic first, then exact-group Boussinesq. Retain the optimized interleaved path as the bounded control. Preserve phase, mean/inertial modes, cross-family projection, vertical velocity and displacement/stratification terms.
3. Wire the qualified execution/backend policy through native runtime and supported MATLAB-loaded paths. Apply final benchmark #23 topology defaults, with bounded pointwise calibration and no process-wide BLAS environment mutation.
4. Qualify independent source builds and representative full workloads, adopt passing defaults, merge reviewable increments and update issue acceptance records. A candidate failing its declared gate remains rejected or deferred with evidence; passing correctness alone does not establish adoption.

The benchmark source is pinned at `6f2e4cd9e2f092433a584645e573d818ecaca42b`. Its committed handoff and final decisions supersede historical primitive sweeps. No repeated DGEMM/ZGEMM packing survey, small-grid timing/crossover work, zero-fill survey, speculative custom arithmetic, or v5 optimization belongs to this goal. New algorithm research requires a demonstrated material residual bottleneck in actual integrated execution.

## Qualification boundaries

Each campaign must freeze its sources, binaries, fixture hashes, workload definitions, effective topology, trial counts and gates before timing. The existing #464 receipts remain historical screening evidence. Reused scientific fixtures retain their original generator/source identities; their outputs must never be relabeled as newly generated.

The principal performance sizes remain 256×256×129 and 512×512×257 where applicable. Small, odd and nonsquare fixtures establish correctness only. Complete native flux, MATLAB-loaded execution where supported, and matched model integration are separate boundaries. Scalar, particle, event/diagnostic and output work must be included rather than inferred from flux-only timings. Exact grouped Boussinesq requires an explicit capacity estimate before generating large fixtures.

Final variable adoption requires at least 10% geometric complete-flux improvement, no declared large profile slower than 1.03× control, paired uncertainty excluding a tie, no peak-memory growth, unchanged scientific checks and prepared execution with no application allocation, plan construction or worker creation. Report preparation, numerical execution, adapters, output, owned capacities, provider lower bounds and fresh-process peak RSS separately. Record rejection and failed runs along with successful evidence.

## Verification ledger

- Confirmed authenticated repository owner `JeffreyEarly`; issue/PR updates and merges are authorized within this goal.
- Confirmed PR #464 merged at the baseline above; started a clean isolated feature branch from fetched main.
- Read workspace instructions and applicable package, caching, documentation and profiling guides.
- Assigned independent derivative implementation, compact integration design and qualification inventory work. Timing campaigns will run without competing builds or numerical jobs.
- Existing large SQG/Hydrostatic and three-family smoke fixtures are available under `/private/tmp/wvm455-variable-*fixtures*`. Available local disk was approximately 19 GiB at goal start; preserve prior evidence and estimate new fixture/output capacity before generating it.
- Derivative implementation: Release `WVPrunedHorizontal` and `WVSpectralOperators` passed; ASan/UBSan `WVPrunedHorizontal` passed. Native and reference coverage includes full frequencies, both axes, Nyquist modes, strided/padded storage, input preservation, plan lifetime and zero prepared allocations.
- Independently built control/candidate workers passed all 18 smoke cases (three families × flux/scalar × three selections) against MATLAB flux or analytical scalar and frozen outputs. Source/binary postflight passed. Harness preparation corrected its Nyquist/cross-term oracle and a missing modal-record include before qualification. No numerical tolerance changed.
- Production MATLAB/forcing/integrator sources are unchanged between fixture source `55dd8ae` and `b1579883`; reuse preserves the original fixture generator and payload hashes. No large performance result is claimed yet.

## Prospective derivative-resource screen (#463)

Before new large timing, compare three independently identified selections: the frozen full-FFT production path at `b1579883`, the prior pruned/streamed path at the same revision, and the bounded-derivative pruned/streamed candidate. Compile the same author-only workers against the two source trees; record both source trees and the separate harness identity. The frozen checkout is `wvm-v4-issue455-variable-control`.

Use the existing independently generated SQG/Hydrostatic fixtures at 256×256×129 and 512×512×257, preserving their original `55dd8ae` provenance and hashes. Compare flux payloads with the stored MATLAB oracle. Add a manufactured horizontal scalar-advection workload containing low frequencies, resolved frequencies outside retained truncation and even-grid Nyquist terms, with depth-dependent amplitudes and supplied constant horizontal velocity. Compare with its independent analytical derivative and the frozen source output. This scalar workload isolates full-grid derivative resources; it does not qualify three-dimensional scalar integration, filtering or event behavior by itself.

For each family/grid/workload run four fresh-process blocks, alternating the three selections in forward/reverse block order, two warmups and four measured calls. FFTW internal workers stay one; pruned horizontal workers stay twelve; matrix backend is Accelerate with the existing process BLAS settings recorded. Run a one-block, no-warmup, one-sample smoke first; it has no timing acceptance role. Keep all reports and sample journals. Retain the first payload per selection/profile plus every failure, and hash then remove only later successful duplicate outputs after comparisons pass. This retention policy bounds new disk use without discarding existing campaign evidence.

Report candidate/prior-pruned and candidate/production time ratios and peak RSS separately. #463 requires no greater than 3% slowdown on declared large representative work and no peak-memory growth; these direct scalar/flux screens inform that decision but do not replace the parent event, independent MATLAB and full-model gates. Freeze the candidate source and build identities before the large screen; retain any failed screen instead of changing its limits after measurement.
