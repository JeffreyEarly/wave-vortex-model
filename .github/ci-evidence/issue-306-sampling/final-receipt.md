# Issue 306 sampling receipt

The final strengthened witness is `TestPortableFieldSamplingMatrix/declaredPortableSamplingMatchesMatlab`. It covers all six families, AA0/AA1, linear/spline interpolation, fixed and event positions, all declared profiles, and moving positions according to the adapter-specific capability mask. Three-dimensional position probes use interior depths; profile requests use varied horizontal indices.

## Commands and providers

Release reference/native command:

```text
MATLAB_PREFDIR=/private/tmp/wvm306-matlab-pref matlab -batch "restoredefaultpath; w='/Users/jearly/Documents/OceanKitRepositories/wvm-v4-cpp-adoption-audit'; addpath(fullfile(w,'tools')); configureCIEnvironment(w,'/Users/jearly/Documents/OceanKitRepositories/OceanKit'); addpath(fullfile(w,'UnitTests')); setenv('WV_FIELD_SAMPLING_DUMP','/private/tmp/wvm-v4-audit-runtime/WVStratifiedQGFieldDump'); setenv('WV_STABLE_FORCING_NATIVE','1'); results=run(testsuite(fullfile(w,'UnitTests','TestPortableFieldSamplingMatrix.m'))); disp(results); assert(all([results.Passed]));"
```

Sanitized reference command used the same MATLAB body with `WV_FIELD_SAMPLING_DUMP=/private/tmp/wvm395-standalone-sanitized/WVStratifiedQGFieldDump` and `WV_STABLE_FORCING_NATIVE=0`.

Final results: Release reference/native passed; sanitized reference passed. Code Analyzer passed with no issues.

## Counts

| Configuration family | Positions | Profiles | Moving |
|---|---:|---:|---:|
| constant-hydrostatic AA0/AA1 | 16 | 13 | 6 |
| constant-nonhydrostatic AA0/AA1 | 16 | 13 | 6 |
| barotropic AA0/AA1 | 8 | 0 | 8 |
| stratified-qg AA0/AA1 | 13 | 10 | 13 |
| hydrostatic AA0/AA1 | 16 | 13 | 16 |
| boussinesq AA0/AA1 | 16 | 13 | 16 |

The constant moving count excludes the ten fields whose generated metadata has `movingPrimitiveChannel < 0`; their fixed/event and MATLAB arbitrary-position checks remain required.

## Hashes

| Artifact | SHA-256 |
|---|---|
| Release probe | `d69c2adb885b8a2d961a151aa109a84556b88db5c6b7022d78b22cd0714d0135` |
| Sanitized probe | `63fe6031b8b0e30668a441da5e54544ee81874ada8236458811f2d74a88e7045` |
| `release-final.log` | `64bac434c7d8cd620ff566293ce034cda3580b5c94dd142d3f226234fff32649` |
| `sanitized-final.log` | `15f93a71ab427c14eedc81f542fe50c54b2959b4eed95bd185b0220289c99eae` |
| `existing-release-reference.log` | `1dfa7db8b8c83eb75a1867bbe3fd1d1da205208528fa26cdaa872ad3efa75d41` |
| `code-analyzer.log` | `3d1245a1fab1c89a398226a21511ecc90dabf26672b0c7c9c8223332ae5f0c9b` |

Source hashes are in `source-sha256.txt`. The earlier `release-matlab.log` and `release-focused.log` are retained as superseded attempts; they predate the interior-depth and varied-profile strengthening and are not evidence for the final witness.

The three existing field-sampling methods were verified reference-only in `existing-release-reference.log`. Their legacy harness did not provide a native provider in this build; this limitation does not apply to the new witness command above.

Retained logs remove trailing line whitespace only. Original and retained hashes are recorded in `../issue-306-assembly/retained-log-normalization.json`; test output content is unchanged.
