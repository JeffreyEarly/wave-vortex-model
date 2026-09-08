# Issues 396 and 315: forcing-tendency diagnostic increment

Branch: `issue-315-forcing-tendency-diagnostics`, based on v4 main `866f66ed419829c751a020646a6f3799bbe7e531`.

## Verification ledger

- #396: normalized RK78 dense-output coefficient alias checks through the integration layout's existing coefficient-family views. Regression coverage exercises legacy/explicit accepted states against legacy/explicit output states, each independently aliased coefficient family, unchanged endpoints, and rejection before evaluation or output mutation.
- #396: Apple Clang ASan/UBSan `output-orchestration` passed, including the pre-existing lazy extension, transactional retry, and accepted-trajectory comparison. Build: `/private/tmp/wvm395-standalone-sanitized`, rebuilt from this branch. Leak detection is disabled locally because this macOS sanitizer does not support it; address and undefined-behavior checks remain enabled.
- #396: Release `output-orchestration` passed using the combined CI build in `/private/tmp/wvm395-release`.
- No MATLAB source or scientific formulas changed in the RK78 fix.

## Diagnostic semantics established from MATLAB

`Operations/SpatialForcingOperation.m` reports the difference before and after each operation in stage/priority order. Spatial diagnostics expose the raw spatial contribution; spectral and amplitude diagnostics reconstruct the difference in the accumulated spectral tendency. Filters and fixed-amplitude operations therefore require the preceding accumulated tendency. Evaluating each forcing independently from a zero accumulator is incorrect.

The diagnostic execution must use the existing resolved forcing instances and coarse operation services. Instance identity and output metadata must be bound before evaluation. Scratch belongs to the observation occurrence, and diagnostic execution must not restore constrained amplitudes or change accepted integration state. Projection must preserve the distinction between raw spatial contributions and reconstructed spectral contributions.

#315 implementation and qualification remain in progress. This ledger is not completion evidence for #315.
