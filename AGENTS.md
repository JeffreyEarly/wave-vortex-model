# WaveVortexModel repository policy

Follow the shared OceanKit workspace instructions as well as this policy.

## Source and artifacts

Keep implementation, tests, reproducible authoring scripts, schemas, and normal documentation in this repository. Do not commit recorded research, benchmark, profiling, calibration, or verification results: this includes raw or summarized datasets, logs, timing tables, generated study figures, archives, and Markdown execution reports. Compression and conversion to another format do not make an output suitable for source control.

Write authoring outputs outside the checkout by default, to a caller-selected directory or a temporary directory. Record execution outcomes in the pull request or issue when needed; do not create a verification ledger in the repository. The quadratic-dealiasing technical note and its supporting material belong in the separate literature repository.

Schemas, configuration, and fixed fixtures that are direct inputs to tests are source dependencies, not records of an experiment. Keep their consumers and purpose explicit. Generated API documentation remains governed by the normal documentation workflow. Do not use these source categories to retain study outputs.

Run `python3 tools/checkRepositoryArtifacts.py` before committing. Update its source-input rules only when adding an actual source dependency. Removing old outputs uses ordinary commits; do not rewrite shared Git history as part of cleanup.

## Verification

Select checks from changed behavior. Artifact and policy cleanup requires artifact/reference checks and CI-routing tests. Changed authoring tools need their directly affected tests. Numerical implementation changes need smoke and affected scientific tests; C++ changes need contracts and sanitizers; dependency/export changes need package checks. Long scientific studies run on the scheduled, release, or explicitly requested extended workflow, not on every PR push or label change.

Keep a brief verification ledger outside the repository. Reuse valid completed measurements when production behavior has not changed. Run one final relevant hosted gate after review; do not repeat successful broad suites for logs, documentation, or test-assertion corrections without a specific new concern.
