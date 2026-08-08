# Authoring tools

The canonical production-source analysis command is:

```matlab
buildtool analyze
```

The task analyzes root runtime files, root class folders, and runtime folders declared in `resources/mpackage.json`. It excludes `UnitTests`, documentation, benchmarks, developer experiments, legacy archives, released snapshots, and authoring tools.

The analyzer uses MATLAB's factory configuration and reports active and suppressed findings. Preallocation and established interface-style advice are visible but nonblocking. The centralized policy in `analyzeProductionCode.m` also records the narrowly accepted multiple-inheritance false positives. Analyzer errors, correctness findings, and unfamiliar identifiers block until reviewed and classified.

Do not add `%#ok` annotations merely to make this report empty. Suppressed correctness findings remain blocking.
