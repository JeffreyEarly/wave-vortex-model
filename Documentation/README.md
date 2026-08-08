# Documentation

`WebsiteDocumentation` contains the canonical hand-authored Markdown sources. The committed `docs` tree combines those sources with generated API pages and version history for GitHub Pages.

Documentation generation is an authoring workflow and requires exactly `ClassDocumentation@1.3.0`. Install that package and its dependencies without adding it to the WaveVortexModel runtime manifest.

From the repository root, rebuild the committed site with:

```matlab
buildtool docs:build
```

The build is performed in clean staging storage, validated, and then installed transactionally. A failed generation or validation leaves the existing `docs` tree unchanged.

To verify that committed output is current without modifying the checkout, run:

```matlab
buildtool docs:check
```

The check performs the same clean generation and validation, then compares it with `docs`. Internal links are checked case-sensitively. Generated drift must be reviewed and committed rather than regenerated later by release automation.
