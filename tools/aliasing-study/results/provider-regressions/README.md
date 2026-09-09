# Released-provider advisory references

These references qualify the current authoring advisory against an explicitly recorded provider release. They do not replace the original [calibration-v1 study](../calibration-v1), and do not claim a new dense or exhaustive interaction survey. Each reference records the fixed sparse advisory's prefix errors and a provenance file containing the provider, OceanKit and WVM revisions, package versions, MATLAB version, full case configuration and request.

## InternalModes 2.0.0-beta.3

The [cal-constant-17 reference](internal-modes-2.0.0-beta.3/cal-constant-17/prefix-errors.csv) was generated with provider tag `v2.0.0-beta.3` at `9ff1b6789a1dd1978736eb86760135909bf9999d`, OceanKit `0a483f5de9c623943944957f05300633511d6079`, and the WVM generator revision in [provenance.json](internal-modes-2.0.0-beta.3/cal-constant-17/provenance.json). The generator and assessment code are committed before the reference is generated, so this revision identifies a reproducible computation rather than the subsequent artifact commit.

Spectral coefficient scaling removes part of the old eigensolve's derivative error. Consequently, the first three quadratic-error estimates change from approximately `[7.9853e-7, 8.7664e-7, 1.1294e-6]` to `[1.0257e-7, 1.0257e-7, 1.9841e-7]`. The five higher-prefix estimates retain their historical values within the existing `1e-7` comparison allowance. This is a numerical-reference update; the acceptance thresholds, requested counts, recommendations, rejection rules, reference qualification and budgets are unchanged.

`TestWaveQuadraticAdvisory` compares all eight prefix errors against this release's values with the same `AbsTol=1e-7` equality assertion. It also checks that the loaded provider version matches the reference. Smaller reported errors are not automatically accepted in place of equality. The independent source-projection, product, reference-gating and count-rejection tests remain in force.

To reproduce, check out the recorded WVM and OceanKit revisions, then run from the WVM authoring repository with a new output directory:

```matlab
addpath(fullfile(pwd,"tools","aliasing-study"));
writeWaveAdvisoryRegressionReference(fullfile(tempdir,"new-wave-advisory-reference"),oceanKitRoot);
```

Here `oceanKitRoot` is the checkout of the recorded OceanKit revision. Compare `prefix-errors.csv`; the new provenance file will record the new generation time. The writer rejects an existing output directory to prevent accidental replacement of historical evidence. When adopting a later provider, generate a separate reference directory, review numerical changes and update the test's selected reference deliberately.
