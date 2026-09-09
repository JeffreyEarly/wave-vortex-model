# Linear mode qualification and experiment adoption

The current linear Boussinesq constructor defaults to `shouldCheckQuadraticAliasing=false` and `shouldAntialias=false`. QG defaults both to `true`. They are independent choices: vertical product qualification and horizontal bandwidth, respectively. Disabling quadratic qualification skips APV self-products, APV/zero-APV cross-products, and sampled wave-product preparation and selection. It preserves independent convergence, fixed-grid Gram checks, explicit count strictness, and physical qualification of every configured endpoint. The construction report says `not-requested` for the omitted evidence.

## Matched-policy comparison

With constant `N2=1e-4`, domain `[1e5 1e5 1000]` m, grid `[8 8 65]`, latitude 30 degrees, and **the same horizontal antialiasing setting (`true`)**:

| Qualification | Wave counts at four positive kappa pages | Inertial | APV | MDA | Quadratic selection trials |
|---|---|---:|---:|---:|---:|
| Linear | 38, 38, 38, 38 | 38 | 38 | 39 | 0 |
| Quadratic | 10, 19, 19, 10 | 38 | 27 | 39 | 12 |

The [machine-readable comparison](LinearModePolicy/matched-policy-counts.csv) records these counts. Its 15.03 s is the combined wall time for both constructions under concurrent local work, not a per-construction timing or a benchmark. That timing predates the bounded APV search; the final regression rerun reproduces the counts. The matching horizontal setting isolates the effect of vertical quadratic qualification; it is an explicit override of the new linear default.

The linear test retains an explicit 38-wave prefix, evolves its high modes with conserved linear energy, and verifies persistence and same-resolution transfer. The same explicit prefix fails the quadratic policy. Changing `quadraticAliasingTolerance` while checks are disabled does not change any family count or trigger product preparation. QG can also explicitly use the linear policy; its separate fixed-boundary resolution limit still applies.

## Balanced candidate construction

Automatic APV quadratic qualification starts with at most 32 candidate modes and doubles the candidate band until a cumulative Gram/quadratic rejection lies inside it, or the original `Nz+4` candidate ceiling is reached. Every product required by the tested prefix is still measured. Acceptance is cumulative, so a rejected prefix rules out every longer prefix; evaluating a larger tail cannot restore acceptance. This changes the search cost, not the product inventory or tolerance defining a prefix. Explicit APV requests solve and strictly assess exactly their requested band. Linear automatic APV selection retains its original candidate ceiling. `assessment.apv.candidateConstruction` records the attempted bands.

The 513-point exponential-stratification QG experiment exposed a candidate-tail failure in the provider: asking for 517 MDA candidates encountered a zero-norm guard before WVM could select the usable physical-grid prefix. A separate 385-candidate probe at `nEVP=1551` selected 321 modes with Gram error about 0.0054; its full candidate band failed the 0.01 Gram criterion. The usable band was therefore strictly inside a valid candidate band.

WVM now catches only that specific normalization failure for automatic MDA candidate construction and brackets a valid candidate count. A shortened search is accepted only when its physical-grid Gram cutoff lies strictly inside the valid candidate band. Exhausting a valid band without establishing a cutoff is an error. Explicit requests remain strict. The construction report records attempted counts and normalization failures; no arbitrary mode cap or weakened provider norm threshold is introduced. Independent balanced references cover the selected prefixes, avoiding an unnecessary invalid reference tail. After bounded convergence refinement, reports may retain rejected candidate evidence beyond the final selected count.

## Verification and scope

The [focused regression ledger](LinearModePolicy/verification.csv) records **108 passing tests** and combines the existing transform, convergence, variable-count, evolution, persistence, transfer, output/restart and shared-contract checks with seven new policy tests. A direct 69-candidate provider comparison reproduces the bounded 32-candidate APV selection and retained-prefix diagnostics. The final candidate-construction changes were followed by a fresh run of the seven policy tests and six automatic-selection tests. Each ledger row identifies its evidence run; this is a consolidation of focused checks, not a fresh full scientific suite.

Testing uses MATLAB R2025b Update 4 on Apple Silicon, WVM based on `96962bab5e85fbfeef94cb224075262d05b54504`, InternalModes `2.0.0-beta.4`, and the declared dependency snapshots at OceanKit `65d9aa2c3de941406dc6bf2cf1937ba5b3dcd1d5`. Tests reset the MATLAB path and load this graph explicitly. These are authoring-consumer checks against released dependencies, not a new exported WVM installation or a WVM release.

Code Analyzer reports zero findings in the 22 files checked together and the subsequently changed balanced-construction helpers. Documentation generation/check has zero drift (2,361 files and 4,825 routes). Whitespace and manifest/snapshot scope checks pass.

The experiment adoption PRs separately record their exact WVM commit pins, reduced evolution/restart checks, construction trials, and saved assessment provenance. QG keeps both endpoints and nonlinear checks. The surface-gravity-wave experiment explicitly omits balanced endpoint anomalies (`g0=Inf, gd=Inf`), preserves its `gramTolerance=1e-8`, and requests the external wave mode only inside its prescribed 30 m wavelength cutoff. Omitting these balanced coordinates leaves the external wave free-surface EVP unchanged. Unpopulated shorter wavelengths do not require wave construction; this does not alter any populated Fourier pair.

The policy is neither exhaustive nonlinear qualification nor evidence for stable v5. Nonlinear Boussinesq dynamics, full beta scientific/install/export gates, and long experiment movies remain separate work.
