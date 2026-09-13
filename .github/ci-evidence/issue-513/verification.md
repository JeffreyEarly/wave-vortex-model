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
