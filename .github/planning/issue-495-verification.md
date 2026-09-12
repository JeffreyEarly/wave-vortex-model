# Prepared RHS benchmark and pipeline screen (#495)

Baseline: merged PR #494, `f65ebf684a403742ed27775de0a2c2aac4a1e2fe`. Required CI passed; #493 closed. The clean v4 main checkout was fast-forwarded. Original benchmark/evidence worktrees and all v5/experiment worktrees are retained untouched.

## Scope and ownership

Root owns compute, candidate source and qualification. One existing implementation worker owns `Benchmarks/prepared-pipeline/`; one independent reviewer audits the pipeline and prior benchmark history. No agent builds or benchmarks concurrently.

The prepared worker measures nonlinear flux plus physical field construction. It deliberately excludes damping, integrators and outputs. Each call starts/ends a fresh evaluation, while immutable matrices, plans and capacity persist. Benchmark validation occurs outside timing and retains source/provider/input identities. This screen cannot establish whole-model gains.

## Verification ledger

- Initial applicable guides: repository AGENTS, C++ optimization workflow, shared caching/profiling/documentation guides read.
- Source/CI: #494 merged and required checks passed; clean source at `f65ebf68`.
- Disk preflight: approximately 5.3 GiB free; no full NetCDF output copies planned for stage screen.
- Existing helper and benchmark review: previous adoption workers already load once, but do not select the current tiled path or use explicit state scopes. New driver adapts their construction/receipt conventions and adds sequential resident-worker commands.
- Host observation at 19:54 UTC: no active experiment/build/MATLAB observed; only Codex exceeds 10% CPU. Recheck and journal during timings.

Subsequent results will distinguish harness validation, source variants, exploratory measurements and adoption qualification. No successful gate is repeated without a relevant source or input change.
