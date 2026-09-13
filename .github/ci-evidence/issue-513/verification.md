# Issue 513 investigation ledger

- Isolated authoring worktree `wvm-v4-issue513`, branch `perf/513-vertical-calculus`, baseline v4.4.0 `9345b79efa441d0ba097f931e1bebf7bb42cc089`. Shared authoring checkout remains v5 and untouched.
- Qualified receipt `20260913T133115356Z-three-interface-benchmark.json.gz` present in external three-interface archive; original source `024add423bf19c682ab5fd793821f398c5e7170f`. Kernel, adapter, MATLAB scientific source and benchmark worker compare unchanged against v4.4.0. Release/package/documentation metadata differs.
- Original endpoint and composite `matched-constant-nonhydrostatic-*-model.nc` fixture payloads absent from workspace and `/private/tmp`. Reconstruct from unchanged benchmark recipe, record new hashes, and distinguish reconstructed-fixture evidence from the original campaign.
- Original compiled composite integration samples remain 114.205, 55.298, 55.641 seconds. No original evidence is discarded or replaced.
- Initial host inspection: no active MATLAB or benchmark workers. Initial disk space approximately 21 GiB. Coordinator alone schedules builds and numerical runs.
- Read shared/local AGENTS, CPP-OPTIMIZATION, profiling and MATLAB style guides. Profiling helper lives in `OceanKit/tools/profiling`, not this repository's `tools/profiling`.
- Prior history checked: spectral-kernel-benchmarks #8, #13, #19–25 and local published decisions. Existing constant retained batched DCT/DST infrastructure is reusable. #94/#160 reject transferring isolated FFT gains or explicit packing wins to whole workloads. This experiment targets the later MATLAB primitive column loop, not the already-batched nonlinear kernel.

## Gates

| Gate | Identity | Result | Invalidated by |
| --- | --- | --- | --- |
| Source equivalence | v4.4.0 versus qualified 024add42 scientific/kernel inputs | Pass | Runtime edits |
| Ownership | `gh api user` = JeffreyEarly | Confirmed | Repository owner changes |
| Original fixture recovery | Workspace and `/private/tmp` exact filename search | Missing | Original payload supplied |

| Frozen baseline build | 88c47263; aggregate 3d565dff… | Pass, validated native provider | Source/provider/toolchain edits |
| Candidate build | c3067ad5; aggregate 7cfa4cc8… | Pass, same qualified provider; MEX be0140d6… | Runtime/provider/toolchain edits |
| Independent source review | c3067ad5 calculus batches, strides, arena, tails | No unresolved arithmetic/lifetime findings; plan counter counts actual invocations | Runtime edits |
| Combined native tests | c3067ad5, Apple Clang 21 | 59/59 pass | Runtime/native-test edits |
| Focused MATLAB tests | c3067ad5, R2025b Update 4 | 8/8 pass, including derivative orders 1–4 and tracer evolution | Runtime/scientific-test edits |
| Code Analyzer | New MATLAB harness/test files | Three benign NASGU warnings in wrapper; no correctness findings | MATLAB edits |
| CI-policy tests | CI route includes new compiled test class | 52/52 pass after installing pinned PyYAML into temporary venv | Routing/policy edits |
| Repository/package/generated artifacts | Candidate scope | Pass | Tracked file/scope edits |
| Documentation check | v4.4.0 plus c3067ad5 | 2052 files, 4197 routes, zero diff; run once | Canonical documentation edits |
| Initial output/control comparisons | All twelve initial fresh-process samples | 20/20 pass at existing 1e-13 + 1e-12 × scale | Runtime/fixture/output edits |
| Supplemental output/control comparisons | Two idle-host candidate supplements | 5/5 pass at same tolerance | Runtime/fixture/output edits |
| Timing qualification | Baseline repeats 1/2/3; candidate 1/2/4 | Composite −58.45% against reproduced slow mode; endpoint −0.77%; all fourteen samples retained | Runtime/provider/protocol/fixture edits |
| Local GCC 14 | Apple SDK | Blocked before source checking by SDK _Alignof parsing; Linux CI required | Supported Linux compiler run |

## Evidence audit

- Candidate repeat 3 in each workload has pre-run macOS mediaanalysisd activity near one core. The pair was retained and excluded from idle-host qualification before supplements were run. The supplement followed an interval measurement of 96.97% idle; its process snapshots have no process above 40% of one core. No other experiments/builds were run concurrently with timed integrations.
- Initial post-cleanup provider inspections fail after the wrapper restores its entry path and exposes a legacy v5 MEX. Before timing, construction, module activation and the harness assertion require the validated native cached provider. Later receipts have loadedBeforeInspection=true and fail at the subsequent `which` check, after the loaded-module path check passes. The supplemental inspections preserve the cache directory on the path and pass. No v5 source or binary was edited.
- The 120.206415 s separate diagnostic retrieves existing FFTW plan wisdom without measured replanning. DCT uses two workers; 41.2% of sampled interpreter wall stacks wait inside vertical calculus. The fast baseline sample has no vertical-calculus dispatch frames. The original 114.205 s sample lacks plan data, so its cause is not claimed as proven.
- Initial provider copy failed install-name identity validation; it was rebuilt in the isolated baseline cache and qualified before timing. Both failure and successful build logs are preserved. Candidate reuses that exact qualified provider.
- No standalone/MATLAB publication campaign, website regeneration, replacement benchmark publication, package release or public API change is part of this task.
- Evidence/report-only additions after c3067ad5 do not change any of the 319 compiled source-identity inputs. Native/MATLAB numerical gates and timing receipts therefore remain applicable. Final tracked-file scope/whitespace check is recorded separately after staging.

Final staged-file check: `git diff --cached --check` and `tools/ci/check_repository.py` pass after evidence/report additions (1754 provenance rows, 75 witnesses; repository boundaries/tracked artifacts pass). No package metadata, released snapshots or website files are in the PR diff.
