# Executable identity guard (#488)

Based on v4 main `f65ebf68`. Only the forward qualification harness and its focused regression tests change; numerical algorithms, receipt schema and tolerances remain unchanged. The shared report boundary checks the actual runner or controlled-stop probe's `report.source.commit` against the declared build source before accepting a report or writing a receipt. Missing/malformed identity fails with an actionable error containing the executable path.

## Verification ledger

- Shared MATLAB style/focused guide and repository instructions read.
- New matching/stale/malformed identity regressions pass 2/2. Tests cover both runner/probe paths and require the stale/expected revisions in the diagnostic. Code Analyzer reports no findings in either changed MATLAB file.
- Initial temporary script used a hyphenated filename and failed before loading tests; corrected to an underscore filename. Original log retained.
- No C++ build required: native runner/probe frozen at `72fc2bdd` were individually checked for that actual embedded revision. Their compiled source inputs are identical to main `f65ebf68`; the original clean detached source worktree declares that identity. New test-source receipts will preserve the distinction between harness commit and actual build commit.
- Regenerate actual six-family forward evidence once to exercise the new boundary for normal and controlled-stop execution. Reuse the unchanged compiler/native/scientific algorithm evidence; do not repeat unrelated suites.
