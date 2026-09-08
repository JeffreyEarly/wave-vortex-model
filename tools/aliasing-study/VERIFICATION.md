# Verification ledger

- Read shared OceanKit instructions, MATLAB style and focused MATLAB guide, package design/release guide, and documentation style guide. No more local AGENTS.md exists in the WVM worktree.
- Confirmed authenticated GitHub identity JeffreyEarly and ownership of WVM. PR 397 is merged; independent authoring worktree starts at its merge commit.
- Recovered the initially missing InternalModes beta snapshot in the separate `wvm400-oceankit` dependency worktree; original OceanKit and package authoring checkouts are unchanged.
- No numerical checks have run yet. Pilot references and policy comparisons remain pending.

## Initial scalar pilot checkpoint

- MATLAB `TestProductProjection`: 4/4 passed. Includes provider trigonometric cutoff, signed-APV equivalence, positive complex/zero handling, and exterior-content exclusion. Engine sources have not changed since this pass.
- Initial pilot completed after correcting the unsupported provider inertial-F adapter and result collection. Saved outputs: `results/pilot-01`; no policy has been scored or frozen.
- Initial missing dependency snapshot was recovered successfully. No required study dependency remains missing. MATLAB emits a startup warning for the unrelated `/Users/jearly/Documents/MATLAB` directory; it did not prevent the tests or pilot.
- Independent derivative convergence, physical source coverage, calibration/withheld comparisons, peak memory, and larger cost check remain pending. The goal is active.
- Generated website sources and runtime/package metadata were not changed; documentation regeneration is not needed at this checkpoint. Final documentation/package/scope gates remain pending for branch handoff.
- Independent Python inventory audit passed: all 224 rows satisfy exact integer vector closure; 930 channel records sum to 26,040 unique products.
- Code Analyzer: five files clean on first pass; driver had only two obsolete suppression comments. Removed those comments and checked the driver again: clean. No numerical changes occurred after the successful pilot.
- Original WVM, OceanKit, and InternalModes checkouts remain clean. All study additions are under the authoring-only `tools/aliasing-study` directory.
