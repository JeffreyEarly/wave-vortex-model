# Reproducing and collecting the bounded T10 evidence

Use the [final report](README.md) for the exact qualified configuration and source revision. This page describes the execution and collection procedure; listing a command does not establish that it completed. The committed [guard execution ledger](evidence/guard-executions.json) records requested commands and actual process outcomes. Scientific pass/fail/inconclusive results remain in their original CSV/JSON ledgers.

## Paths, revisions and clean MATLAB setup

The retained evidence root is `/Users/jearly/Documents/OceanKitRepositories/thermal-readiness-t10-evidence`. Binary MAT/NetCDF files and logs remain there; [artifacts.csv](artifacts.csv) records paths relative to that root, byte sizes and SHA-256 hashes. Small result files are copied under `evidence/raw/`, with original bytes verified by the [source/copy index](evidence/source-copy-index.csv). These paths are provenance, not runtime package dependencies.

The [recovery source inventory](evidence/recovery-script-sources.json) preserves MATLAB bootstraps, setup helpers and Python queue/guard source. Extract the selected script's `source` text to a new file. Replace the original workspace prefix in both the script and its literal helper `run(...)` paths. Replace every evidence output path with a fresh destination; do not append a new configuration to old files. Preserve links to required inputs such as the scientific cache, frozen closure, saved diagnostic bases and checkpoint. Relative paths inside authoring utilities resolve from the WVM checkout.

The source inventory distinguishes a script requested by a recorded guard command, a literal helper of such a script, and a file present without recorded invocation. Recorded commands are authoritative, but the scripts were not independently hash-locked at every historical invocation. The inventory therefore describes retained source at collection time, not proof that every historical source byte or helper line executed. A queued script without a completed guard result is not completed evidence.

The final measured WVM source is `9fc8bd98ca2ef6007eaa6ef947ea3756f063a51a`, including the reviewed `eig(...,'nobalance','vector')` construction correction and the pre-integration forcing capture. Earlier regenerated measurements precede that capture and retain their distinct provenance in the ledgers. Their merged T9 baseline was `abe98510ba3ad24276c2af2bd89c80b24209b568`; that earlier commit alone does not contain all T10 authoring drivers. The dependency graph is OceanKit `1873071fe2dfc2678490df1b0252e5071e9d9715`, InternalModes beta.5 `8d9503e5c7c6e4b0432a5c30b42638829a8b3f37`, Distributions 2.0.0, SplineCore 2.2.0, chebfun 5.7.0, NetCDF 1.0.2 and ClassAnnotations 1.2.1. Read the recorded host/runtime metadata for each invocation; the primary measurement runtime is R2026a Update 4. Preserve released snapshots and experiment pins.

Each fresh thermal process starts with the retained `recovery/setup.m` pattern:

```matlab
restoredefaultpath;
cd(wvmRoot);
addpath(fullfile(wvmRoot,'tools'));
configureCIEnvironment(wvmRoot,oceanKitRoot);
p = string(strsplit(path,pathsep));
bad = contains(p,'/internal-modes');
if any(bad), rmpath(char(join(p(bad),pathsep))); end
assert(contains(which('IMInternalModes'),'/InternalModes-2.0.0-beta.5/'));
assert(numel(which('IMInternalModes','-all')) == 1);
maxNumCompThreads(4);
```

## Serial guarded execution

Run one MATLAB batch at a time. On this Mac, Codex must launch local `matlab -batch` outside its sandbox because of the Qt/NEON startup restriction. The guard also requires process-inspection and signalling access. Use the existing [guard](../../../tools/guardThermalReadiness.py); do not replace it with an unbounded launcher or raise a recorded limit after a cutoff.

```bash
t10_workspace=/Users/jearly/Documents/OceanKitRepositories
t10_wvm="$t10_workspace/wave-vortex-model"
t10_run="$t10_workspace/thermal-readiness-t10-evidence-new"
python3 "$t10_wvm/tools/guardThermalReadiness.py" \
  --directory "$t10_run/guard/bootstrap" --limit-gib 8 --seconds 900 -- \
  matlab -batch "run('$t10_run/recovery/bootstrap.m')"
```

The bootstrap/helper files and new output root must be prepared before this example is invoked. Preserve the original guard contract's limit and duration when reproducing a measurement. Later actual-grid/refinement jobs use their separately recorded limits; the example's eight-GiB construction limit is not a universal workload limit. The guard writes `contract.json`, `result.json`, `memory.csv` and `output.log`. A nonzero return code, memory/wall cutoff, missing result, or failed scientific gate must remain visible. The earlier simple guard's `reason="completed"` can accompany a nonzero command return code; process success requires both fields to agree.

## Construction, basis freezing and dependent blocks

1. **Construct the authoritative scientific cache.** `bootstrap.m` calls `thermalReadinessCase(...,cacheFile=...)`, saves construction evidence and runs the radius/response audit. `scientific64.mat` stores scientific arrays, initial coefficients and a case manifest. Restore from those arrays for compatible later cases; do not repeat scientific construction merely to restore a trajectory.

2. **Freeze the two distinct APV uses.** `diagnostic64.m` qualifies and saves the 64-mode diagnostic basis at 129/257 stored depths, then separately saves the canonical six-mode historical closure in `closure64.mat`. The horizontal-only authoring variant zeros its vertical rates while preserving the physical horizontal law. No optional damping uses neither closure. Offline diagnostic choices never redefine online dynamics.

3. **Invoke named study blocks separately.** `runThermalReadinessStudy` supports `time`, `product`, `native`, `horizontal`, `thermal`, `mean`, `closures`, `activity`, `cold10`, `cold100`, `peak10`, `zero10` and `zero100`. Use the recorded duration and explicit observation offsets, especially for dense process-budget checks. The product comparison constructs 769/1537/3074 rules with fixed scientific maps; the 769-point workload/restart scripts consume `windows/product/product769/initial-case.mat`. They do not relabel the original 1537-point cache. Keep new case identities and the measured reference uncertainty for every changed configuration.

4. **Restore in a separate fresh process.** The initial restart script runs `qualifyThermalReadinessRestart(initial,folder,...)`. Its fresh counterpart removes all `InternalModes`/`internal-modes` path families, asserts both `IMInternalModes` and `IMSolverSpectral` are unavailable, then invokes `qualifyThermalReadinessRestart([],folder,restoreOnly=true)`. The checkpoint folder is an intentional input to that continuation. Reproduction of the whole pair needs a fresh folder and checkpoint; a previously used continuation destination cannot be reused. Diagnostic restoration likewise uses saved basis arrays with `shouldConstructMissingBases=false`.

5. **Measure and aggregate the named workloads.** Run the selected `workload*` scripts individually, then the matching `resources*.m` script. Preserve cold versus manufactured states, forcing multiplier, closure and product count in the descriptors. Do not pool the historical APV control into a thermal throughput range. Keep construction, canonical/file restoration, first RHS, integration, output and analysis costs separate. Missing allocated-byte, checkpoint or analysis measurements remain unknown.

The exact scripts and guard commands, rather than this abbreviated order, specify which invocations were requested and their original paths. Run only the bounded block needed for the intended check; this procedure does not launch an annual or multi-year campaign.

The recorded thermal-bandwidth block stops before a completed 513-direction trajectory when its 32 GiB guard fires. Prepared initial arrays are not a completed reference. The subsequent offline 257/385 comparison retains **INCONCLUSIVE REFERENCE** despite a largest QGPV difference of 0.648431%; see [Accuracy.md](Accuracy.md). Reproduction preserves this cutoff. Obtaining the missing finer reference requires separately scoped work within the existing memory ceiling, not an automatic retry with a larger cap.

## Historical APV control

The historical environment uses clean detached dependency checkouts under a separate `pinned/` workspace. Run the experiment repository's existing `setupExperiment(pinnedWorkspace)` on a clean MATLAB path, then add only the current WVM `tools/` folder. `pinnedAPVv2.m` additionally verifies resolved symbols stay inside the historical checkouts before calling `benchmarkPinnedThermalReadinessAPV`. Its [recorded paths](measurements/pinned-apv-cold-v2/resolved-paths.json) identify all seven exact dependency commits: WVM `4ec07256476ee57ceee23d70422baec65d1f31a4` and InternalModes beta.4 `f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51` are deliberately independent of the thermal beta.5 graph.

When rebuilding missing checkouts, use a new isolated workspace at the commits in `free-surface-qg-experiments/dependencies.json`; verify every checkout is clean. Do not move sibling authoring branches, edit dependency manifests, change snapshots or globally prune worktrees. The [pinned provenance](measurements/pinned/provenance.json) records revisions, expected symbol files and hashes of the unchanged experiment setup inputs. Preserve the failed first baseline attempt as failed evidence; it is not a successful timing sample.

## Final collection after MATLAB is idle

The retained `recovery/collectFinalArtifacts.py` uses only Python's standard library. It refuses active MATLAB batches, guards or the recorded timing queues. The `/bin/ps` idle check also requires execution outside the Codex sandbox on this host. Run it only after all measurement jobs and result writers are idle; do not redirect its output into the evidence root being hashed.

```bash
python3 "$t10_workspace/thermal-readiness-t10-evidence/recovery/collectFinalArtifacts.py" \
  --evidence-root "$t10_workspace/thermal-readiness-t10-evidence" \
  --report-root "$t10_wvm/Documentation/Validation/Issue441"
```

The collector copies small CSV/JSON files byte-for-byte, preserves failed/partial records, and writes LF-normalized indexes. It hashes retained MAT/NetCDF/log/script files without copying binary/log bulk into git. Historical checkout payloads are excluded in favor of `pinned/provenance.json`. It refuses existing output destinations; a subsequent collection requires new `--copy-subdir` and `--artifact-index` names and updated documentation links. A changed file or partial collection is an error, not a finished index.

The [collection metadata](evidence/collection.json) separately sums recorded post-restart MATLAB-guard and other-guard elapsed times, including failures, cutoffs and process startup while excluding nested guards from the sum. These are not CPU time or a reconstructed task-lifetime budget. Lost pre-reboot time, unguarded work and any overlap remain outside that accounting.
