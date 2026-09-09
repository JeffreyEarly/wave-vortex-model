# Issue 289 MATLAB qualification ledger

Scope: new `UnitTests/TestPortableForwardIntegration.m` on v4 base `2e1cc199`. No MATLAB production code, public API, or file format changed.

## Development checks

1. Smoke 1 failed during authoring: `timeStepForCFL` belongs to `WVModel`, not the transform. Corrected the test helper.
2. Smoke 2 failed portable preflight: constant-stratification moving-point sampling does not support `qgpv`. Particles now track the common supported `u` field; Eulerian `qgpv` output remains.
3. Smoke 3 failed the stopped-status assertion: the optional argument guard used `nargin < 7` instead of `nargin < 6`. Corrected the helper.
4. Smoke 4 exposed a numerical difference: the exponential tracer differed by 1.73969e-6 against a 2e-7 bound. C++ differentiated vertical modes omitted by MATLAB's retained-Nj derivative. The core agent corrected C++; steps and tolerances stayed unchanged.
5. The four variable/QG cases exposed an invalid barotropic mooring fixture and a separate particle difference. Public MATLAB supports moorings only in 3D, so the barotropic fixture omits that observer. SQG, Hydrostatic and Boussinesq had coefficient/field/tracer errors near 1e-15 but particle errors near one metre.
6. Direct MATLAB sampling confirmed the second particle's spline velocity is exactly zero in the shifted-grid extrapolation region, while its linear velocity is nonzero. The core agent corrected C++ to preserve existing MATLAB semantics. Proof: `/private/tmp/wvm289-sample-particles.log`.
7. The original constant-hydrostatic reference scenario passed against the tracer correction with its original 4-second steps and tolerances. Maximum saved-output error was 1.278e-15; tracer and particle errors were zero. Log: `/private/tmp/wvm289-matlab-tracerfix.log`.
8. Reduced duplicate model reconstruction in verification while retaining every assertion. Each configuration now keeps its own temporary artifact folder.
9. Code Analyzer R2025b on the final test source: one file, zero active, suppressed or blocking findings. Log: `/private/tmp/wvm289-matlab-analyzer.log`; receipt: `/private/tmp/wvm289-matlab-final-analyzer.json`.

## Final qualification

- Test commit: `b59498d904a68509ab915e47bf908ed4c3e13450`.
- Exact test SHA256: `485a4600d74e5c71d903cfe545726852877359b299bfaedd5811d011ccd88895`, unchanged since the passing Code Analyzer run.
- Immutable C++ source commit: `2ae8eaa32e820aa5042f62b5eaefc969254bdf94`, including both scientific compatibility corrections.
- Six parameterized tests passed, covering twelve configuration/provider rows and 144 completed continuation/destination comparisons. Total test time: 259.187909125 seconds.
- Maximum relative errors: coefficients 2.066742935413747e-15; fields 1.1229037321661902e-15; tracer 1.5542843854036618e-15; saved output 2.6396901016129792e-15.
- Maximum particle position error: 1.8189894035458565e-12 metres. Held coefficient error: zero, including 216 output records between accepted steps.
- Minimum measured evolution: unconstrained coefficients 0.001561655595010085 relative; particle motion 0.2326754131022426 metres; tracer 8.125184943286179e-5 relative.
- Both accepted-step and output-occurrence stop profiles reached complete checkpoint time 37, then continued to time 137. Both output destinations were independently restored and continued in MATLAB.
- Main log: `/private/tmp/wvm289-matlab-final.log`.
- Test receipt: `/private/tmp/wvm289-matlab-final-receipt.json`.
- Twelve source/binary-bound fragments: `/private/tmp/wvm289-matlab-final-evidence`.
- Machine-readable maxima, timing and artifact hashes: `/private/tmp/wvm289-matlab-verification-summary.json`.
- The exact catalog JSON, SHA256 `c9b669fa92d5556526ce9cefac8b9847f52c1ea15c8ab3b00db0f3454adfaef9`, is an untracked execution input in this worktree, copied at the coordinator's request and excluded from the test commit.
- `git diff --check` passed. Required CI, collector validation, documentation and GitHub integration remain with the coordinator.

Every local MATLAB batch ran outside the sandbox as required. The existing startup warning for `/Users/jearly/Documents/MATLAB` did not prevent verification.
