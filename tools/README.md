# Authoring tools

The canonical production-source analysis command is:

```matlab
buildtool analyze
```

The task analyzes root runtime files, root class folders, and runtime folders declared in `resources/mpackage.json`. It excludes `UnitTests`, documentation, benchmarks, developer experiments, legacy archives, released snapshots, and authoring tools.

The analyzer uses MATLAB's factory configuration and reports active and suppressed findings. Preallocation and established interface-style advice are visible but nonblocking. The centralized policy in `analyzeProductionCode.m` also records the narrowly accepted multiple-inheritance false positives. Analyzer errors, correctness findings, and unfamiliar identifiers block until reviewed and classified.

Do not add `%#ok` annotations merely to make this report empty. Suppressed correctness findings remain blocking.

## Documentation

Documentation generation requires the authoring-only package `ClassDocumentation@1.3.2`. Install that exact package and its dependencies before running either task; it is intentionally absent from `resources/mpackage.json` because it is not a runtime dependency.

```matlab
buildtool docs:build
buildtool docs:check
```

`docs:build` generates into clean staging storage, validates front matter, mathematical Markdown, internal routes, and generated navigation, and transactionally replaces `docs`. `docs:check` performs the same build in temporary storage and fails on any difference from the committed tree without changing the checkout. Both tasks print the resolved ClassDocumentation version and path before generation.

The required documentation CI job also builds the committed tree with GitHub Pages' Jekyll action and runs `validateRenderedWebsite` on the resulting HTML. The rendered-site validator requires ordinary content pages to contain their main content and heading, rejects source Markdown that survived rendering outside code elements, and detects malformed MathJax delimiters or expressions split across table cells. Valid delimiters remain in Jekyll output for browser-side MathJax. Rendered output is temporary diagnostic data and is never committed.

The OceanKit release workflow continues to call `build_website_documentation(rootDir=...)`. That entry point uses the same exact dependency check, clean generator, validation, and transactional replacement as `docs:build`.
