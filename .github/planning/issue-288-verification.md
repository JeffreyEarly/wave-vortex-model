# Issue 288 verification ledger

Scope: controlled C++ integration termination on v4 main `23aa3f0d2e436e51b423231dcb16c5bd0a90258a`. MATLAB production code, authored output schedules and the existing persistence schema remain compatible. This ledger records isolated development verification; combined native performance qualification and required CI belong to final integration.

## Contract

- Additive source APIs preserve existing overloads and custom integrator consumers. RK4, CFL-selected RK4, RK23, RK45 and RK78 poll control at accepted boundaries; rejected attempts and RHS loops do not poll.
- A request is latched. Generic output drains the accepted interval. Model-file output drains to an authored checkpoint containing coefficients and required dynamic blocks in every destination. Results distinguish request time from actual accepted stop time, and callback, output and numerical failures.
- An immediate create/replace request may advance to the first actually persisted checkpoint. Append can stop without a step when each destination already has the current complete checkpoint. Source cursors alone do not establish committed destination records.
- No common restart occurrence before the target produces an explicit output failure without target overrun. A stopped result always exposes accepted state, never interpolated output state. Lookahead advances bounded scratch cursors without retaining schedule history or changing committed execution cursors.
- SIGINT requests the same graceful path; a second SIGINT aborts normally. SIGTERM remains an abort. The reusable runner installs no signal handlers.
- Empty observer collections now carry the canonical `AnnotatedClassArray="WVObservingSystem"` metadata. Independent MATLAB reopen exposed this missing C++ writer marker; no MATLAB reader relaxation was necessary.

## Focused C++ verification

Reference Release build: `/private/tmp/wvm288-build`. ASan/UBSan RelWithDebInfo build: `/private/tmp/wvm288-sanitized`, with `-fsanitize=address,undefined -fno-omit-frame-pointer`. Both compile with the repository warning policy.

| Gate | Result / local evidence |
| --- | --- |
| Output orchestration, model output, model facade and standalone runner | Four Release suites passed in `/private/tmp/wvm288-initial-stop-tests.log`; the subsequently expanded complete NetCDF suite passed in `/private/tmp/wvm288-netcdf-final.log`. |
| Same four suites with ASan/UBSan | 4/4 passed, 15.82 seconds; `/private/tmp/wvm288-sanitized-final.log`. |
| Final low-memory lookahead regression | Release and ASan/UBSan passed; `/private/tmp/wvm288-allocation-test.log` and `/private/tmp/wvm288-allocation-sanitize-test.log`. |
| Source and architecture policies | 6/6 passed; `/private/tmp/wvm288-source-policy-final.log`. |
| Source consumer and extension contracts | 2/2 passed after final public API edits; `/private/tmp/wvm288-final-source-contracts.log`. |
| Whitespace and scope | `git diff --check` passed; changes confined to PortableRuntime and the verification ledger/receipt. |

Regression coverage includes exact callback-free versus always-continue coefficients, additional state blocks, step/rejection/RHS counts and retained state workspace for all four methods; no stop lookahead allocation on continuing runs; initial and dense stops; unequal checkpoint/dynamic-block rates across multiple files; bounded no-match search; source-defined typed schedule cursors; sink termination and failed sibling retry; callback exceptions, including nonstandard exceptions; numerical failure; and injected allocation failure during lookahead followed by successful retry. Actual CLI signal tests cover initial and dense requests, repeated SIGINT and unchanged SIGTERM behavior.

Development failures were corrected and the affected tests rerun. In particular, exact equality in a source-defined schedule assertion was replaced by the existing accepted-time coincidence tolerance, and the dense SIGINT harness gained enough integration horizon to avoid finishing before signal delivery. These do not change event grouping or integration rules. No broad or optional Full CI was run in this isolated worktree.

## MATLAB restart qualification

Independent validation used MATLAB R2025b Update 4 and the public `WVModel.modelFromFile` and continuation APIs. The final receipt is retained in `.github/ci-evidence/issue-288-matlab-restart.json` (original: `/private/tmp/wvm288-scoped-matlab-final12.json`); its scripts and component logs record the actual invocation history. Eight regular cases passed before a separate initial-case harness endpoint assertion failed; only the four initial cases were rerun after correcting that endpoint.

| Cases | Restored state | Continuation result |
| --- | --- | --- |
| RK4, RK23, RK45, RK78, each with two independent destination files (8) | Exact coefficients, particles and tracer at `5e-6` | Advance to `1e-5`; 3 coefficient and 9 dense records, original records preserved and all outputs finite. |
| RK4 immediate create and replace, each with two independent files (4) | Exact coefficients, particles and tracer at `1e-5` | Public schedule extension and advance to `3*(5e-6)`; 2 coefficient and 8 dense records, original records preserved and all outputs finite. |

All 12 source snapshots remained hash-identical. The authored endpoint `3*(5e-6)` is slightly greater than the literal `1.5e-5`; the corrected harness uses the authored endpoint rather than asserting output beyond its requested target. Each row explicitly records the existing undamped-fixture warning, “The nonlinear flux has no damping and may not be stable.” This is not warning-free qualification.

The final writer source SHA-256 is `63fd048d8dc124808259f6ac6d9480bf76b74fcf9864565743d9f970257e46e2`, matching fixture generation and the final MATLAB receipt. Permanent C++ tests also inspect and restart the complete multi-file graph, including exact empty-observer metadata and create/replace/append boundary cases.

## Integration handoff

Final independent CLI review found that a successful dense-output warmup stop could be overwritten by the measured phase, and warmup callback exceptions used the generic numerical-failure report. The addendum skips measured integration after a warmup stop, aggregates callback and committed-output counters across phases, and shares structured failure reporting. Six regressions cover dense and non-dense warmup with a one-shot stop, always-continue callback and throwing callback. The complete standalone-runner suite passed in Release (6.73 seconds, `/private/tmp/wvm288-warmup-test.log`) and ASan/UBSan (13.13 seconds, `/private/tmp/wvm288-warmup-sanitized-test.log`). Writer and orchestration sources remain unchanged, so the MATLAB receipt still matches the qualified source exactly.

The coordinator owns combined native FFTW qualification, the matched no-stop runtime/retained-memory comparison against qualified main, source provenance updates, required hosted CI and GitHub issue closure. Continuing runs add bounded scalar bookkeeping, with no new state-sized workspace; the existing 3% performance/memory budget still requires that combined measurement. Checkpoint-dependent stop latency and explicit failure when no suitable checkpoint remains are intentional documented limitations, not claims of immediate asynchronous cancellation.
