# Tracked scientific artifacts

Repository checks accept scientific inputs and current evidence through exact paths and roles in `artifact-inputs.json`. These include fixtures, schemas, contracts, benchmark scoring references, published datasets, source configuration, and current qualification receipts. Register a new input explicitly with its scientific purpose in the pull request. Existing directories do not authorize new files.

Historical outputs are frozen by exact path and SHA-256 in `artifact-baseline.json`. Normal validation never adds entries or refreshes hashes. New unregistered logs, raw outputs, and receipts fail the cheap repository check; use Actions artifacts for transient run output. The output suffix inventory also covers JSON, NetCDF, MATLAB data, archives, and plain-text output. Source files with an output-like suffix, such as CMakeLists.txt, have explicit registrations.

Baseline entries cannot be added after initial registration, modified, or silently removed. Retirement requires the old path, digest, reason, and an immutable source revision. CI verifies that source revision is reachable in the branch history, predates deletion, and contains the original bytes. Retain a pre-deletion implementation commit through a normal merge when a retirement manifest names that commit; squashing it away is not permitted. Existing retirement records cannot be rewritten or reintroduced as active artifacts.

Run `python3 tools/ci/check_repository.py` for the working tree, or run `python3 tools/ci/check_artifact_policy.py --base BASE_SHA` to validate a complete proposed transition. Hosted pull requests use their merge base; pushes use their before revision. The one-time baseline bootstrap is tied to the exact revision recorded in the checker.

Before retiring receipts, use `tools/ci/audit_artifact_candidates.py` on a clean implementation revision. Inspect structured path and hash references, source manifests, historical reports, and directory-reader search results. The artifact baseline's own inventory references are administrative records, not scientific consumers. A hash reference in another historical report is sufficient reason to retain a candidate for separate review.

Website data deduplication and historically referenced campaign records are outside this cleanup. Scientific source, numerical tolerances, current receipts, pinned historical family reports, fixtures, schemas, scoring references, and published downloads retain their original bytes.
