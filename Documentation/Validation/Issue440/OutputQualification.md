# T9 committed-output qualification

The committed-output integration passed its focused checks on 14 September 2026. Six new output-analysis tests and 38 existing shared reader/restart tests passed. A separate MATLAB process restored the thermal trajectory and diagnostic APV transform with InternalModes absent, then reproduced all three committed diagnoses exactly. This qualifies read-only record selection, saved-array restoration and diagnostic reproducibility; it does not establish nonlinear campaign accuracy or performance.

## Environment and dependency identity

The run used MATLAB `25.2.0.3177638 (R2025b) Update 5`, `MACA64`, on macOS 26.6.2 build 25G83, with `maxNumCompThreads(2)`. Source changes are the T9 implementation based on v5 commit `e513f3f81971539a0a74ecf1f856e9bca7d7e132`; the enclosing PR and master qualification record identify the integrated source revision. The authoring manifest remains WaveVortexModel 4.3.0; no release was published by this qualification.

`configureCIEnvironment` loaded the following released snapshots from OceanKit commit `1873071fe2dfc2678490df1b0252e5071e9d9715`:

| Dependency | Version |
| --- | --- |
| InternalModes | 2.0.0-beta.5 |
| ClassAnnotations | 1.2.1 |
| NetCDF | 1.0.2 |
| SplineCore | 2.2.0 |
| Distributions | 2.0.0 |
| chebfun | 5.7.0 |

InternalModes tag `v2.0.0-beta.5` is tag object `18edbcf70ffb690c2e85917f02fa7cae9c147459`, resolving to commit `8d9503e5c7c6e4b0432a5c30b42638829a8b3f37`. The setup asserted unique `IMInternalModes` resolution inside `OceanKit/InternalModes-2.0.0-beta.5`; sibling authoring repositories and older snapshots were excluded. The WVM dependency requirement is now `^2.0.0-beta.5`. Existing snapshots and historical experiment pins were preserved.

## What was exercised

[`analyzeThermalAPVOutput`](../../../tools/analyzeThermalAPVOutput.m) opens the source read-only and restores its scientific arrays once. It discovers the unique complete coefficient stream using the same extracted worker as [`initFromNetCDFFile`](../../../@WVTransform/initFromNetCDFFile.m). Record loads modify only the utility's private analysis transform. Every selected record goes through the public `apvDecomposition` method; the caller's diagnostic transform is unchanged.

The shared discovery worker was compared against its preceding implementation and is byte-identical apart from two help-comment lines. It preserves canonical-family discovery, legacy field fallbacks, ambiguity rejection and the local-time requirement. Finite-prefix selection remains owned by `WVModelOutputGroup.committedRecordCountForGroup`; the utility does not implement another commit protocol.

| Gate | Result |
| --- | --- |
| New `TestThermalAPVOutput` tests | 6 passed, 0 failed, 0 incomplete |
| `TestNetCDFHandleOwnership`, `TestFreeSurfaceOutputRestart`, `TestThermalOutputRestart` | 38 passed, 0 failed, 0 incomplete |
| Code Analyzer: public reader, shared discovery worker, analysis utility and output test class | 0 messages |
| Owned-file whitespace and extraction-scope checks | Passed |
| Fresh-process diagnosis with InternalModes absent | Passed for 3 committed records |

The six new tests cover:

1. Scalar-snapshot agreement with in-memory diagnosis, exact authoritative object-state preservation, unchanged source bytes and warning-free file cleanup.
2. A diagnostic-array fingerprint that is unchanged by target coefficient/clock changes and changes with the projection quadrature.
3. A nested complete stream at `analysis/states`, selected-record ordering, last-committed selection and exclusion of a staged payload tail.
4. Bounded default history, explicit selections and rejection of duplicate, fractional, mixed-infinite, out-of-range or over-limit requests.
5. Uncommitted streams, commit holes, duplicate complete streams, missing families and missing local time, with the shared error identifiers and unchanged file bytes.
6. Cleanup after a diagnostic quadrature error, allowing a subsequent writable open.

The default analysis history is limited to the first 100 committed records. An explicit `indices` selection preserves its requested order; `maximumRecords` is the explicit storage bound. History contains coefficients and physical accounting, not reconstructed volume histories. `provenance.rateSource` is `"none"`: the utility does not recompute forcing or claim time-integrated budgets. Source hashing, scientific restoration, record loading and diagnosis have separately reported timings.

## Fresh-process control and recorded identity

The control uses constant stratification on a 500 km × 500 km × 1 km domain. The source has an 8 × 8 horizontal grid, 65 stored depths, 17 thermal directions and three original MDA coordinates. The diagnostic transform has 129 stored depths, six APV modes and two MDA coordinates; its MDA coefficients are not used to replace the source mean. Both endpoints are active. Analysis uses 259 physical Gauss points.

The test saves three complete coefficient records at 17, 23 and 47 seconds, with a fourth staged payload lacking its finite time commit. It also saves the independently constructed diagnostic transform through the existing annotated writer. Scientific construction occurs in the preparation process. A fresh process removes every InternalModes snapshot path and asserts that both `IMInternalModes` and `IMSolverSpectral` are unavailable before restoring either transform.

The fresh process reproduced the coefficients, means, inventories, spectra, residuals and numerical metadata with `isequaln`. The only excluded result field is `metadata.isConstructionAssessmentAvailable`: the original diagnostic construction report is transient and is absent after canonical restoration. The complete original report is retained once in analysis provenance. Actual selected counts and scientific arrays remain authoritative; unavailable requested constructor counts are not inferred.

The recorded run produced these identities:

| Artifact or diagnostic identity | Recorded value |
| --- | --- |
| Thermal source bytes | 162838 |
| Saved diagnostic transform bytes | 322137 |
| Thermal source SHA-256 | `00860a1f193df260476fb481da558856b8a89102c4473318ad1d180bdc27fcd1` |
| Diagnostic numerical-array SHA-256 | `2552c14da7f852fe57746177ed547a9c913695dd1bd114ac3bac06427dfbcb5f` |
| Committed records | 3 |
| Physical times, seconds | `[17 23 47]` |

The source hash covers the entire file, including staged bytes, and is compared before and after analysis. The diagnostic hash covers named and shaped geometry, Fourier coordinates, APV/zero-APV scientific arrays, physical quadrature depths and sampled stratification. Its encoding is recorded as UTF-8 name/shape headers followed by real and imaginary column-major little-endian float64 values. It is computed once by the authoring utility, outside the runtime map-application loop. Target state and clock are deliberately absent from this identity. The saved diagnostic file is still needed to recover the authoritative arrays; a fingerprint cannot replace it.

The fresh-process checks require equality against the reference generated from the same saved arrays, not these literal example hashes across new releases or independently reconstructed bases. Raw NetCDF and MAT artifacts are generated locally and are not committed to the repository.

## Reproduce from the repository

Run from the `wave-vortex-model` authoring root with its sibling `OceanKit` checkout at the revision above. Save the following MATLAB block as a scratch script with a valid MATLAB filename and invoke it using `matlab -batch "repositoryRoot=string(pwd); run('path/to/script.m')"`. The command captures the repository before `run` visits the scratch script's directory. On the local Apple Silicon host, run MATLAB outside the Codex sandbox as required by the workspace policy. The code derives workspace paths from the repository root and does not depend on the original machine's temporary directory.

```matlab
restoredefaultpath;
cd(repositoryRoot);
workspaceRoot = string(fileparts(repositoryRoot));
addpath(fullfile(repositoryRoot,"tools"));
configureCIEnvironment(repositoryRoot,fullfile(workspaceRoot,"OceanKit"));
entries = string(strsplit(path,pathsep));
siblings = startsWith(entries,workspaceRoot+filesep) ...
    & ~startsWith(entries,fullfile(workspaceRoot,"OceanKit")+filesep) ...
    & ~(entries == repositoryRoot | startsWith(entries,repositoryRoot+filesep));
if any(siblings), rmpath(char(join(entries(siblings),pathsep))); end
provider = string(which("IMInternalModes"));
assert(contains(provider,fullfile("OceanKit","InternalModes-2.0.0-beta.5")));
assert(isscalar(which("IMInternalModes","-all")));
maxNumCompThreads(2);

files = ["UnitTests/TestThermalAPVOutput.m", ...
    "UnitTests/TestNetCDFHandleOwnership.m", ...
    "UnitTests/TestFreeSurfaceOutputRestart.m", ...
    "UnitTests/TestThermalOutputRestart.m"];
results = runtests(files);
disp(table(results));
assertSuccess(results);
for file = ["@WVTransform/initFromNetCDFFile.m", ...
        "+WVInternal/groupContainingCompleteVariableSet.m", ...
        "tools/analyzeThermalAPVOutput.m","UnitTests/TestThermalAPVOutput.m"]
    assert(isempty(checkcode(file,"-id")));
end

addpath(fullfile(repositoryRoot,"UnitTests"),fullfile(repositoryRoot,"UnitTests","Fixtures"));
outputFolder = fullfile(tempdir,"wvm-t9-apv-output");
TestThermalAPVOutput.prepareWithoutProviderStudy(outputFolder);
fprintf("Prepared fresh-process reference in %s\n",outputFolder);
```

Exit that MATLAB process. Run the next block in a **new** MATLAB process, again starting in the authoring repository root and using `matlab -batch "repositoryRoot=string(pwd); run('path/to/verificationScript.m')"`. The same `tempdir` location is used on this host; if preparing and verifying elsewhere, explicitly provide the folder containing `thermal.nc`, `diagnostic.nc` and `reference.mat` to both static methods.

```matlab
restoredefaultpath;
cd(repositoryRoot);
workspaceRoot = string(fileparts(repositoryRoot));
addpath(fullfile(repositoryRoot,"tools"));
configureCIEnvironment(repositoryRoot,fullfile(workspaceRoot,"OceanKit"));
entries = string(strsplit(path,pathsep));
remove = contains(entries,filesep+"InternalModes-") ...
    | (startsWith(entries,workspaceRoot+filesep) ...
    & ~startsWith(entries,fullfile(workspaceRoot,"OceanKit")+filesep) ...
    & ~(entries == repositoryRoot | startsWith(entries,repositoryRoot+filesep)));
if any(remove), rmpath(char(join(entries(remove),pathsep))); end
maxNumCompThreads(2);
addpath(fullfile(repositoryRoot,"UnitTests"));
assert(isempty(which("IMInternalModes")));
assert(isempty(which("IMSolverSpectral")));
TestThermalAPVOutput.verifyWithoutProvider(fullfile(tempdir,"wvm-t9-apv-output"));
```

The expected terminal result is `Provider-unavailable APV output analysis: 3 committed records, exact saved-array diagnosis.` The verifier checks source and diagnostic-array hash equality and preservation of the supplied APV transform's authoritative state.

## Verification notes and scope

During development, the first successful-test run exposed duplicate NetCDF close warnings in cleanup. The utility now closes through its cleanup object exactly once; the scalar test explicitly verifies warning-free analysis. An initial fresh-process comparison was superseded while the core metadata schema and numerical implementation were still changing. Its reference was regenerated after the agreed schema was installed, and the separate fresh-process run above passed. These were corrected development observations, not relaxed acceptance gates.

Both documented MATLAB blocks passed Code Analyzer with zero messages. Their revised scratch-script path handling was exercised by running the preparation section and the complete provider-unavailable verification block in separate processes; the fresh-process gate passed again. Already successful test suites were not repeated solely for these documentation edits. Local links, code fences and whitespace checks passed.

Setup emitted the existing MATLAB package-path ordering and Java X11 warnings. They did not block the gates. The output qualification requires no historical literature assets or saved campaign trajectory, and no required check in this scope remains blocked. Whole-PR documentation, package installation/export and final integration checks are recorded by the master T9 ledger rather than claimed here.
