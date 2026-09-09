# Captured density solver qualification ledger

Read-only full-state loads; no integrations or production edits by the qualification agent. MATLAB package setup used configureCIEnvironment and pinned OceanKit dependencies. Every MATLAB batch used escalation required by the shared Apple Silicon guidance.

## Original production baseline

Original source commit: 6fed53701480d031fcc1d495fbd6cfe2dc7cd593. The qualifier invokes production full-density moment extraction once and reproduces existing optimizer settings using the production residual/Jacobian/parameterization. Full report records input hashes and source hashes.

| Day | Solver | Solve s | Exit | Max raw residual | Jacobian rank |
|---|---|---:|---:|---:|---|
| 3000 | lsqnonlin | 0.226924 | 3 | 3.91183e-07 | 23/41 |
| 3000 | fminsearch | 0.269709 | 0 | 2.33378e-06 | 23/41 |
| 3250 | lsqnonlin | 0.0280267 | 3 | 7.27601e-07 | 28/84 |
| 3250 | fminsearch | 0.640751 | 0 | 1.98867e-05 | 28/84 |

fminsearch exhausted its existing 10,000-iteration bound on both states. lsqnonlin exit3 was function-change termination. Direct raw Jacobian rank deficiency did not imply unacceptable local sensitivity: eight smooth log-gap initial perturbation comparisons produced maximum inverse differences of 0.100m and 0.356m.

## Legendre comparison rejected

Direct full-density stable recurrence of standard shifted Legendre moments was compared without converting saved raw powers. Analytic Jacobian directional checks were below 6.4e-7 relative error. Matrix rank improved, but distribution error and low-order mass moments worsened. Raw lsq density Wasserstein errors were only 0.519% and 0.794% above the exact optimal fixed-mass quantization lower bound; equal-weight Legendre increased this excess to 38.4% and 44.3%. The lower bound is an exact discrete parcel approximation bound, not an interpolated no-motion profile truth.

## Local damped QR prototype

No production implementation. Solve augmented [J;sqrt(lambda) I] least squares, with finite-candidate/cost-decrease/model-prediction acceptance. Initial lambda=0.001*max(sum(J.^2,1)), cubic gain-ratio update with at least a factor 1/3, doubled rejection multiplier, damping overflow guard. Bounds: 2000 iterations,5000 evaluations. Explicit gradient1e-12, step1e-12, relative-cost1e-12 termination statuses. No normal equations.

Both JAMES states reached gradient tolerance in ~0.10s (~300 evaluations), residuals4.64e-11/2.07e-11. Four exact linear/exponential rest cases preserved the original density exactly; four perturbed-start rest cases reached residual<=4.8e-11 and density error<=1.7e-5 kg/m3. Failure-path/control regressions remain necessary before production.

| Day | Mean eta lsq (m) | Mean eta QR (m) | QR W1 excess over floor | Max sampled gradient change | Mean APE relative change |
|---|---:|---:|---:|---:|---:|
| 3000 | -0.13141399 | -0.0094457756 | 0.20363% | 2.292% | -0.14044% |
| 3250 | 0.032241547 | 0.0036153756 | 0.017795% | 2.7017% | -0.17763% |

APE remained nonnegative and sampled stratification gradients remained positive. PCHIP inverse profiles differed from default lsq by up to~2m; improvement in physical summaries supports a fallback candidate, not a claim of identical legacy results or exact continuous truth.

## Root recurrence qualification

Root changed moment extraction, while the agent preserved the original saved target vectors. Current recurrence produced all43/86 moments within5.55e-17/1.11e-16, at0.0341/0.3634s versus historical0.3683/6.4765s. Current source SHA e017bdf72d42e3366881cdd48868cd52581edc582f0b235146487ebb2af32fc4 also includes root stable-rest/dimension-validation changes.

## Verification and limitations

- Original qualifier final batch exit0, both states complete, changed-file Code Analyzer zero findings.
- Retained failures: wvm391-density-3000.log and -3000-rerun.log exposed expression transpose binding in helper metrics before optimizers; wvm391-density-successful-batch.log exposed empty struct-array assignment after one fast solve. Corrected; timings in final report come only from complete final-batch run.
- Root calculus batch first attempted a hyphenated temporary sensitivity-script name, which MATLAB rejected. Renamed to wvm391CompactSensitivity.m; subsequent eight comparisons passed. No calculus rerun was required.
- Day3250 load warns about an original serialized GMSpinUpExperiment function-handle path that is absent. State loading/density computation completes from retained model data; this was not a verification-blocking missing asset.
- Grid-refinement/snapshot differences are not a controlled convergence sequence: day3000 and3250 are different physical times and resolutions.
- Empirical CDF and discrete quantization compare exactly weighted samples. Linear-inverse/empirical-CDF errors include quadrature and interpolation artifacts; they must not be presented as true eta errors.
- Timings are single-run local observations, not a controlled performance benchmark. No full CI or integrations were run.

## Artifact hashes

- `/private/tmp/wvm391DampedLeastSquares.m` SHA256 `b667666ecd5e2f413f5ff961029b0ba25592b594acb22f957f527d6ce2d5e9d8`
- `/private/tmp/wvm391QualifyDampedLeastSquares.m` SHA256 `a40038bf476be09a855bc678b845ee79ae2b3fe21a65c58e16de226b8552b2a3`
- `/private/tmp/wvm391AssessDampedPhysics.m` SHA256 `d27456451d3a052fb30b4d90b529b12a35327956f1ac995d1a284dd39db08c1a`
- `/private/tmp/wvm391LegendreQualification.m` SHA256 `b4bc2a09a9b86ec4898c9c54a94e3fe3039e37425af5ce485a8cfa356672f525`
- `/private/tmp/wvm391CompactSensitivity.m` SHA256 `1b1bc3df86615a32fd3bfd972799815e29f8de2417882c73d05ee6567344dcd5`

## Foundation implementation after the experiments

The root subsequently added the qualified raw-moment damped algorithm as an explicit solver option, leaving automatic selection unchanged. It added input/budget validation, retained termination diagnostics, rejected unqualified operation results before caching, and fixed zero-iteration reporting with a regression. The exact stable-rest shortcut and equivalent recurrence are implemented. The shared cubic calculus remains an isolated primitive pending transform-level/default adoption. Thirty focused methods pass across affected batches; no claim of default eta_true/APE/APV adoption or C++ compatibility follows from this record.
