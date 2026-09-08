# Verification ledger

- Read shared OceanKit instructions, MATLAB style and focused MATLAB guide, package design/release guide, and documentation style guide. No more local AGENTS.md exists in the WVM worktree.
- Confirmed authenticated GitHub identity JeffreyEarly and ownership of WVM. PR 397 is merged; independent authoring worktree starts at its merge commit.
- Recovered the initially missing InternalModes beta snapshot in the separate `wvm400-oceankit` dependency worktree; original OceanKit and package authoring checkouts are unchanged.
- At the initial planning checkpoint no numerical checks had run; subsequent evidence is recorded below.

## Initial scalar pilot checkpoint

- MATLAB `TestProductProjection`: 4/4 passed. Includes provider trigonometric cutoff, signed-APV equivalence, positive complex/zero handling, and exterior-content exclusion. Engine sources have not changed since this pass.
- Initial pilot completed after correcting the unsupported provider inertial-F adapter and result collection. Saved outputs: `results/pilot-01`; no policy has been scored or frozen.
- Initial missing dependency snapshot was recovered successfully. No required study dependency remains missing. MATLAB emits a startup warning for the unrelated `/Users/jearly/Documents/MATLAB` directory; it did not prevent the tests or pilot.
- Independent derivative convergence, physical source coverage, calibration/withheld comparisons, peak memory, and larger cost check remain pending. The goal is active.
- Generated website sources and runtime/package metadata were not changed; documentation regeneration is not needed at this checkpoint. Final documentation/package/scope gates remain pending for branch handoff.
- Independent Python inventory audit passed: all 224 rows satisfy exact integer vector closure; 930 channel records sum to 26,040 unique products.
- Code Analyzer: five files clean on first pass; driver had only two obsolete suppression comments. Removed those comments and checked the driver again: clean. No numerical changes occurred after the successful pilot.
- Original WVM, OceanKit, and InternalModes checkouts remain clean. All study additions are under the authoring-only `tools/aliasing-study` directory.

## Physical-source study and calibration checkpoint

- Added actual wave generalized-energy source projections for both frequency signs; retained signed MDA and actual inertial source pairings at zero output. `TestSourceProjection`: 4/4 passed against WVM's actual source route, including derivative-equation and mean-family checks. A subsequent test-property rename only removes Code Analyzer shadowing suggestions.
- The initially attempted derivative formula was corrected for MDA's pressure integral. The failed run's configuration is preserved in `source-pilot-01`.
- `source-pilot-02` preserves the full short-domain physical survey. Diagnostic `source-pilot-03` establishes that opposite-boundary products fail the independent EVP-product reference check despite globally converged modes. No policy scores use those inconclusive results.
- The componentwise derivative norm was replaced as an admission gate by the documented positive H1 norm before calibration. Original componentwise diagnostics remain available, and the independent product-level EVP gate is mandatory. Full `source-pilot-05` passes all final reference and fixed-family gates. See `SOURCE-PILOT.md` for the scientific rationale and preserved earlier pilot results.
- Four frozen calibration cases completed. Every case passes reference and fixed-family gates. Version-2 score tables separate quadratic-only dense count loss from additional loss beyond the linear gate. Their supplementary quadratic diagnostics show that fixed and targeted sparse selectors match all 12 dense calibration counts, with zero false acceptance and zero quadratic-only count loss.
- `TestSparseStudyPolicies`: 3/4 passed initially; the remaining test failed only because the saved error is single precision and its expected value was double. Corrected the assertion conversion and reran that failing method: passed. Adversarial tests demonstrate detection of unseen failures, independent linear/quadratic loss reporting, monotone stress coverage, and inconclusive-reference handling.
- Independent Python audit confirms all valid vector closures, no duplicate interactions, the exact physical channel inventory, product totals, and calibration decision claims in all four cases.
- Code Analyzer completed for the source/scoring batch. No correctness findings; three logical-indexing performance suggestions are retained. Test-property shadowing suggestions were addressed separately.
- Policy selection and zero count margin are frozen in `policy-freeze.json` before accessing withheld nonlinear results. Withheld validation and the larger sparse/independent sample remain pending.
- Full per-product MAT files are preserved locally and checksummed in `results/mat-artifact-manifest.json`. Large MAT files are not Git fixtures; reproducible source plus machine-readable CSV/JSON result tables are versioned. The original tracked scalar-pilot MAT remains unchanged.
