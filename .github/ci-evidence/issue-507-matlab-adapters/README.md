# All-family MATLAB adapter qualification in progress

The production source at `6c7095d7` implements all six configurations. The local native Release suite and combined MATLAB adapter checks pass in the recorded scope. `qualification-progress.json` keeps source/binary identity and pending gates explicit. No release, installed/export performance claim or final standard-portable-parity decision is made by these development receipts.

The first combined MATLAB run has four failures, preserved in its CSV. `matlab-legacy-repair.csv` records the successful four-method correction; runtime source was unchanged. Analyzer receipts similarly retain the original inventory assertion failures and their successful test-only repair. Do not treat either original failing session as a successful session.

The later installed-package gate passed at `46b4d787`: all six compiled configurations were exercised from an MPM-installed read-only source tree, with all 1,275 exported files unchanged after the external-cache build. ATS PR #10 merged with its complete hosted qualification passing against that WVM pin.

`constant-regression-investigation.json` records a subsequently discovered performance regression. The initial 271 ms constant RHS included a one-thread FFTW configuration error. Restoring the established 16-thread FFTW setting reduced it to 166 ms, but the previous adapter measured 79 ms. The adapter PR and release remain gated while the remaining diagnostic materialization/projection cost is investigated. These single-process screens are not a completed paired performance campaign.

The subsequent fused coefficient boundary passed the focused native forcing/kernel tests and seven MATLAB consumer/lifecycle methods, including raw-first versus coefficient-first cache reuse and a modified nonlinear density correction. `fused-boundary-verification.json` records the checks and independent boundary review. Frozen performance and final-source integration qualification remain pending.

Canonical shared-field reuse and the sealed coefficient-only RHS are recorded in `shared-and-sealed-boundary-verification.json`. All six families pass the focused routing and numerical checks, including custom consumers and invalidated leases. The three-pair Constant campaign at `8aab84c1` measured a 3.76% regression against the preserved foundation adapter; it does not pass the predeclared 3% timing gate. Profiling identified duplicate MATLAB workload checks for the next bounded correction. The native numerical algorithm remains unchanged.

`final-source-qualification-progress.json` records 54/54 native tests, 11/11 affected MATLAB checks, and fresh six-configuration forward integration with both providers at `114c7354`. Documentation regeneration passes with 2,052 files and 4,197 routes. Two equivalent scalar-predicate corrections clear Code Analyzer. The stronger Constant timing comparison and final installed/export/ATS qualification remain pending.
