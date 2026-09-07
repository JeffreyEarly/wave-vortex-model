# Issue 294 forcing catalog foundation

Historical foundation record. The subsequent implementation and qualification are recorded in [issue-290-294-verification.md](issue-290-294-verification.md).

Scope: the user authorized the audited next step—establish the shared inventory/schema and map existing evidence before implementing closures. Work starts from v4 main `c242756efd0329bea38427823b7f07fd0354ee40` on `issue-294-forcing-catalog-foundation`. This is the catalog foundation, not completion of #294 or new forcing implementation.

## Delivered

- A JSON Schema for the initial forcing slice of `portable-compatibility-matrix-v1`, the implementation/evidence supplement, deterministic generated JSON and a generated test-only C++ header.
- Twelve stable MATLAB identities across six baseline configurations: hydrostatic/nonhydrostatic constant stratification and Barotropic QG, each with antialiasing off/on. Thermal damping is explicitly excluded as under development. The generator compares the documented inventory with every supplied forcing source file.
- MATLAB construction, declared forcing types and actual attachment determine applicability and stage/priority. Only specific known constructor/attachment rejections are classified as scientific incompatibilities; unexpected errors stop generation.
- Seventy-two rows: 42 applicable with a C++ factory, 19 applicable without one, and 11 scientifically incompatible. All acceptance remains pending. Structural validation cannot promote factory availability or mapped test names into qualification; `requireComplete=true` rejects the foundation.
- Mapped existing C++ unit and MATLAB contract/continuation test functions with exact symbol validation. C++ checks registry versions, availability and implemented stage/priority against the generated rows. The existing Barotropic QG continuation test consumes catalog case selections while retaining its seven individual cases, two compositions and numerical tolerances.

## Findings preserved

Explicit antialiasing, horizontal damping, vertical damping and vertical diffusivity remain unimplemented (#290–#293). MATLAB construction/attachment also accepts narrow-band geostrophic forcing on both constant-stratification configurations; the C++ registry supplies only its Barotropic QG factory. Four baseline constant-stratification rows therefore remain implementation gaps assigned to #294, not incompatibilities. This probe establishes construction/attachment, not new numerical qualification of narrow-band forcing on those transforms.

The catalog's six configurations describe the baseline inventory. They do not constitute exhaustive coverage of odd/even grids, selected mode layouts, forcing payloads, ordered compositions or provider choices. Existing evidence links do not establish every such combination. Later transform milestones extend this same slice; #306 assembles the complete catalog. The initial schema and readiness gate intentionally prohibit qualified-support claims until acceptance is implemented.

## Verification ledger

- MATLAB generation ran against current v4 and the configured OceanKit package snapshots. Initial probe failures for omitted fixed-amplitude `name` and the explicit pseudo-topographic Barotropic QG rejection were corrected in the generator. No production MATLAB behavior changed.
- Four `TestPortableForcingCompatibility` methods pass, including deterministic regeneration and negative tests for missing/duplicate rows, stale versions, invalid configurations, unresolved evidence and false readiness claims. Reran this focused suite after fixing JSON array serialization; no numerical code changed.
- Existing `TestPortableRuntimeCompatibility/matlabWriterBarotropicQGForcingMatrixMatchesMatlab` passes with catalog-derived case selection, including MATLAB → C++ append → MATLAB restoration for all seven individual cases and two ordered compositions.
- Native-enabled AppleClang build of `TestWVForcingCompatibility` and CTest `forcing-compatibility-catalog` pass. The initial new-target invocation preceded CMake regeneration and found no target; explicit reconfiguration and the actual build/test then succeeded.
- Draft 2020-12 JSON Schema and generated JSON validate with `jsonschema` installed only in a temporary verification directory. A schema check exposed singleton JSON collections; the generator now preserves arrays explicitly. No Python or JSON Schema library dependency was added to the repository or runtime.
- Code Analyzer initially found one `isscalar` suggestion in the new validator; corrected. The existing continuation test retains its unrelated pre-existing unused `outputFile` assignment at line 108. Final Code Analyzer reports zero messages for all three new MATLAB files. `docs:check` passed (2026 files, 4145 routes, zero failures and no generated differences).

## Scope and remaining work

No production MATLAB classes, C++ numerical/runtime implementation, public persistence formats, package manifests, website sources, or released snapshots were edited. New MATLAB files are authoring tools and tests. This task did not modify the separate v5 checkout; another task advanced that branch during the work. Required task assets were available.

Next: #290's explicit closure implementation, followed by the other baseline gaps and exact-pair acceptance. Keep #294 open. Publication/integration of this working branch is not claimed by this local ledger.
