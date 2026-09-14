# InternalModes beta.5 dependency qualification

T9 raises the supported InternalModes floor from the exact beta.4 package to `^2.0.0-beta.5`. Routine CI and native package verification use the released beta.5 snapshot to exercise that floor. This dependency change does not release WVM v5 or change its scientific tolerances. Historical study pins and released snapshot payloads remain unchanged.

## Verified revisions and package graph

| Item | Verified value |
| --- | --- |
| InternalModes version | `2.0.0-beta.5` |
| Annotated version tag | `v2.0.0-beta.5`, tag object `18edbcf70ffb690c2e85917f02fa7cae9c147459` |
| Peeled source revision | `8d9503e5c7c6e4b0432a5c30b42638829a8b3f37` |
| OceanKit release export and all three CI pins | `1873071fe2dfc2678490df1b0252e5071e9d9715` |
| Exported InternalModes directory tree | `6235a985fe2ac7952a71ea6478ac59ae856a5543` |
| Snapshot path relative to workspace | `OceanKit/InternalModes-2.0.0-beta.5` |
| Clean-path test environment | MATLAB R2025b Update 5, `25.2.0.3177638`, `MACA64`, two computation threads |
| WVM source manifest version | `4.3.0`, unchanged |

Read-only remote tag and branch inspection confirmed the [InternalModes tag](https://github.com/JeffreyEarly/internal-modes/tree/v2.0.0-beta.5) and the [OceanKit export commit](https://github.com/JeffreyEarly/OceanKit/commit/1873071fe2dfc2678490df1b0252e5071e9d9715). Local tagged manifests and the provider changelog identify the same release. The provider adds shared construction preparation and mode-local MDA null-norm classification while preserving public APIs and scientific tolerances.

The clean runtime path contained Distributions 2.0.0, SplineCore 2.2.0, chebfun 5.7.0, InternalModes 2.0.0-beta.5, NetCDF 1.0.2 and ClassAnnotations 1.2.1. Documentation continues to use ClassDocumentation 1.3.2. Both legacy `InternalModesWKBSpectral` and V2 `IMInternalModes` resolution are checked by the native installed-package consumer.

## Manifest update and native version-range check

The authoring manifest was changed through the public MATLAB MPM API, run from the WVM package root:

```matlab
package = matlab.mpm.Package(pwd);
package.updateDependency("InternalModes","^2.0.0-beta.5");
```

MATLAB R2026a performed this write. Inspection of its output confirmed that only InternalModes `compatibleVersions` changed; package identity, version, dependency IDs, exported folders and MATLAB compatibility floor were preserved. No JSON was edited directly.

A separate R2025b process with isolated preferences tested MPM's native range semantics. Every scratch package was created through `mpmcreate`; `mpmsearch` performed the actual version filtering. The following complete script reproduces that check:

```matlab
restoredefaultpath;
versions = ["1.9.9","2.0.0-beta.4","2.0.0-beta.5","2.0.0-beta.6","2.0.0-rc.1","2.0.0","2.0.1","2.7.0","3.0.0-beta.1","3.0.0"];
root = string(tempname); mkdir(root);
cleanup = onCleanup(@()rmdir(root,'s'));
for versionNumber = versions
    location = fullfile(root,"T9RangeProbe-"+versionNumber);
    mkdir(location);
    mpmcreate("T9RangeProbe",location,Version=versionNumber,ID="1d3d1e8c-a70d-4ab4-93d7-bdaea68f970e",Install=false);
end
repository = mpmAddRepository("T9RangeProbe",root);
repositoryCleanup = onCleanup(@()mpmRemoveRepository(repository));
packages = mpmsearch(Name="T9RangeProbe",VersionRange="^2.0.0-beta.5",VersionSelectionPolicy="all",Repository=repository);
assert(isequal(sort(string([packages.Version])),sort(versions(3:8))));
```

Save the script as `/tmp/t9CheckDependencyRange.m`. The recorded command was:

```bash
MATLAB_PREFDIR=/tmp/t9mpmPrefs PATH=/Applications/MATLAB_R2025b.app/bin:$PATH matlab -batch "run('/tmp/t9CheckDependencyRange.m')" > /tmp/t9CheckDependencyRange.log 2>&1
```

Create the isolated preference directory before invocation. Run local MATLAB outside the sandbox as required by the workspace policy. The scratch repository was removed and no provider was installed or modified.

| Candidate versions | Result |
| --- | --- |
| `2.0.0-beta.5`, `2.0.0-beta.6`, `2.0.0-rc.1` | Accepted |
| `2.0.0`, `2.0.1`, `2.7.0` | Accepted |
| `1.9.9`, `2.0.0-beta.4` | Rejected |
| `3.0.0-beta.1`, `3.0.0` | Rejected |

The experiment passed. It verifies native resolver behavior; it does not claim scientific qualification of unreleased future provider versions.

## Focused compatibility checks

Save the following script as `/tmp/t9DependencyTests.m` and invoke the command below from the WVM authoring repository. The explicit environment path remains valid while MATLAB `run` temporarily changes to the script directory. It loads the released snapshots through the existing CI helper, excludes sibling authoring checkouts and explicitly verifies that the older provider snapshot is absent:

```matlab
restoredefaultpath;
repositoryRoot = string(getenv("T9_WVM_ROOT"));
assert(isfolder(repositoryRoot));
workspaceRoot = fileparts(repositoryRoot);
cd(repositoryRoot);
addpath('tools');
configureCIEnvironment(repositoryRoot,fullfile(workspaceRoot,'OceanKit'));
entries = string(strsplit(path,pathsep));
siblings = startsWith(entries,string(workspaceRoot)+filesep) & ~startsWith(entries,string(workspaceRoot)+"/OceanKit/") & ~(entries==repositoryRoot | startsWith(entries,repositoryRoot+filesep));
if any(siblings), rmpath(char(join(entries(siblings),pathsep))); end
assert(contains(string(which('IMInternalModes')),'OceanKit/InternalModes-2.0.0-beta.5'));
assert(numel(which('IMInternalModes','-all'))==1);
assert(~any(contains(string(strsplit(path,pathsep)),'InternalModes-2.0.0-beta.4')));
maxNumCompThreads(2);
import matlab.unittest.TestSuite;
suite = TestSuite.fromFile('UnitTests/TestReleaseVerification.m');
qg = TestSuite.fromFile('UnitTests/TestWVTransformFreeSurfaceQG.m');
methods = ["endpointConfigurationsHaveCanonicalShapesAndMDAConstraints","automaticModeCountsAreSelectedIndependently","storedTransformsMatchOnePassFixedQuadratureSelection","omittedEndpointDefaultsRetainSignedAPVAndUseMajorant","canonicalFamiliesRoundTripIndependentlyAndTogether"];
suite = [suite,qg(endsWith(string({qg.Name}),"/"+methods'))];
automatic = TestSuite.fromFile('UnitTests/TestAutomaticFreeSurfaceModeSelection.m');
suite = [suite,automatic(endsWith(string({automatic.Name}),'/automaticFamiliesShareBalancedPolicyAndExposeEvidence'))];
thermal = TestSuite.fromFile('UnitTests/TestFreeSurfaceThermalQG.m');
suite = [suite,thermal(endsWith(string({thermal.Name}),'/snapshotWithoutProvider'))];
results = run(suite);
assertSuccess(results);
files = ["tools/configureCIEnvironment.m","tools/verifyWaveVortexModelPackage.m","UnitTests/TestReleaseVerification.m","UnitTests/TestFreeSurfaceThermalQG.m"];
for file = files, assert(isempty(checkcode(file,'-id'))); end
```

The original run used the equivalent script with explicit workspace paths. This command reproduces it without embedding a machine-specific workspace root:

```bash
T9_WVM_ROOT="$PWD" PATH=/Applications/MATLAB_R2025b.app/bin:$PATH matlab -batch "run('/tmp/t9DependencyTests.m')" > /tmp/t9DependencyTests.log 2>&1
```

All **16 tests passed**, with no failed or incomplete tests. The five existing APV/MDA tests retain their previous scientific gates. The automatic-construction test checks the shared balanced policy across transforms. The thermal restoration test now removes the resolved provider root and asserts `IMInternalModes` is unavailable; its former hard-coded beta.4 exclusion would have silently left beta.5 available.

Code Analyzer reported **zero findings in all four files** at this dependency checkpoint. Later T9 edits to the installed-package consumer require the final integration Analyzer gate. `git diff --check` passed. Searches found no remaining beta.4 path assumptions in active unit tests or CI workflows. Historical authoring study setup and evidence were deliberately preserved.

Read-only revision and preservation checks, from the workspace root:

```bash
git ls-remote https://github.com/JeffreyEarly/internal-modes.git refs/tags/v2.0.0-beta.5 'refs/tags/v2.0.0-beta.5^{}'
git ls-remote https://github.com/JeffreyEarly/OceanKit.git refs/heads/main
git -C OceanKit rev-parse '1873071fe2dfc2678490df1b0252e5071e9d9715:InternalModes-2.0.0-beta.5'
git -C OceanKit diff --exit-code HEAD -- InternalModes-2.0.0-beta.5
```

No dependency check was blocked. Native installed/exported package qualification and the final coherent documentation build are recorded with the overall T9 integration evidence; they were not duplicated by this dependency subtask.
