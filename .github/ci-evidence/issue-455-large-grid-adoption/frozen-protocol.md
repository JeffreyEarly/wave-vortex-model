# Large-grid constant schedule qualification (#455)

## Owner-directed scope

PR #461 integrated the compact candidate at `107894a120da8f2aaa545101d74190a34c38974b`. The owner subsequently accepted the 19–21% integration penalty at 32×24×33 and explicitly declined small-grid optimization. Issue #460 is closed as not planned. That timing result no longer blocks adoption. Scientific correctness, lifecycle, saved-file compatibility and memory requirements remain in force.

This protocol is recorded before new measurements. It completes larger-grid qualification of the existing selected implementation; it does not retune workers, find a size crossover, or overwrite the original #358 protocol and rejected/partial records. The earlier worker screen remains exploratory. All final timing below uses new complete campaigns, excluding every earlier interrupted sample.

## Frozen identities

- Reuse the original frozen control `8d08ba48b554a84b9920e349e6d4c69dccd6c0dd` and the existing compiled candidate whose production source digests match integrated `107894a1`. Preserve original build provenance; do not describe reused artifacts as rebuilt from the merge commit.
- Verify all native, model-runner, MEX, provider and fixture hashes against the retained receipts before execution. Record a new campaign manifest linking those original receipts to current production-source equivalence, current author harness hashes, this protocol and the owner-directed scope change.
- Retain the four independent MATLAB flux fixtures at 256×256×129 and 512×512×257. Verify their source-generator and scientific MATLAB compatibility with current main. Generate new independent MATLAB references for the six large model profiles below.
- Keep the selected policy unchanged: horizontal outer 12, horizontal FFTW internal 1, Type-I internal 16, coefficient workers 2 and pointwise workers 12, including the existing 4096-element serial threshold. No new policy selection is part of this campaign.

## Complete nonlinear flux

Run hydrostatic and nonhydrostatic profiles at both calibration sizes, antialiasing on, through native standalone and MATLAB-loaded boundaries. Each boundary uses eight alternating fresh-process control/candidate pairs per profile, two excluded warmup calls and seven uninstrumented measured calls per process. Use each process median, equally weight profiles and bootstrap paired log ratios with 10,000 resamples and seed 358.

Require geometric candidate/control flux time at most 0.90, each profile at most 1.03, and overall paired 95% upper endpoint below 1.00. Each boundary must pass separately. Require independent MATLAB maximum scale-normalized and relative L2 error at most 1e-10; candidate/control limits remain 2e-12 and 1e-12 respectively. Preserve original fixture-specific limits.

## Representative large integration

Use six profiles: hydrostatic and nonhydrostatic coefficient-only cases at both sizes, plus nonhydrostatic composite cases at both sizes. Composite cases evolve a tracer and two particles, write ordinary full-volume `u`, and evaluate one off-step dense `u` output at time 0.75. All profiles use fixed RK4 with dt 0.5, final time 2: exactly four accepted steps and sixteen RHS evaluations. This shortened integration bounds the cost at large grid sizes while measuring repeated complete RHS execution; setup is reported separately. It is not a long-duration stability experiment.

Each profile uses two excluded warmup pairs and eight measured alternating fresh-process pairs. Compare all saved scientific variables, exact times, schema and work counts against frozen C++ and newly authored independent MATLAB references, retaining the existing narrow documented MATLAB output-group history provenance exclusion. No numerical tolerance changes. Require each large-profile integration ratio at most 1.03. Small-grid restart/lifecycle evidence remains valid scientific coverage, with its timing explicitly exempted by the owner.

## Memory and execution discipline

For each execution boundary, require no owned-memory growth relative to matched control. Require complete-process lifetime peak RSS geometric ratio at most 1.00 and paired 95% upper endpoint at most 1.03. Model accounting includes full retained and maximum-live storage, including optional tracer/observer/output resources. Preserve the compact base `4C+6R` and scalar `max(4C,H)+6R` accounting and configured warmed allocation freedom.

Serialize authoritative timing with no competing builds, MATLAB jobs or benchmark campaigns. Record host topology, environment and original artifact identities. Preserve failures without optional reruns triggered solely by unfavorable results. Report setup, uninstrumented flux, integration, complete process lifetime and memory separately.

Available local disk space is approximately 44 GiB. Retain original fixtures and independent MATLAB references, all metadata/logs/comparison results, and the first complete measured output pair for each profile. After successful independent MATLAB and paired C++ comparisons and persisted hashes, remove only later successful generated payload duplicates (including successful model warmups). Keep failed/current outputs. This retention rule is prospective and does not change numerical comparisons.

## Default promotion and handoff

Promote the compact schedule only after the remaining large-grid gates pass. Update CMake, header fallback defaults, private MATLAB build defaults, source-selection metadata and affected expectations coherently. Preserve explicit frozen-schedule selection and truthful reporting for already installed MEX binaries. MATLAB public APIs and existing saved-file behavior remain unchanged.

Qualify the actual fresh default build, affected native/sanitizer contracts, MATLAB MEX checks, current source consumer, and any source-bound lifecycle receipts invalidated by promotion. Run the required repository checks once for the final coherent change. Commit, push, merge with required CI, and update #455/#358/#310 with the measured decision. Variable-stratification matrix execution follows this increment.

## Verification ledger

- Current v4 checkout is clean at `107894a1` before authoring changes; v5 checkout and benchmark-repository edits are untouched.
- Original four flux fixtures and six executable/module artifacts exist; executable hashes match the retained final provenance. Candidate production-source digest equivalence was independently checked against the merge.
- Read applicable package-design, package-release, documentation and profiling guides. No repository-local AGENTS.md was found.
