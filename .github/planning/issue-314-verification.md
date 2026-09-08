# Issue #314 verification ledger

Scope: extend the MATLAB-authoritative portable variable catalog on v4 after #304 / PR #384. MATLAB scientific source, public behavior, save defaults, package manifests, dependencies, released snapshots and v5 are unchanged. Numerical evaluation and persistence remain in #305; forcing-tendency computation remains in #315.

## Implemented contracts

- 76 stable catalog identities, preserving all 23 original records exactly against the immutable legacy test fixture.
- 666 rows harvested from actual registered annotations and callable standard factories across six transform families and both antialias settings. Each row retains exact dimensions, units, descriptions, complexity, time/cache flags and attributes, with configuration-specific dependency ordinals, component identity, coordinate roles and layout contracts.
- Conditional true-profile dependencies and explicit no-motion solver selection. Fourteen reusable intermediate contracts have event-scoped lifetimes.
- Five forcing-channel templates are harvested through `SpatialForcingOperation`. Construction binds qualified forcing graph instances and detects collisions after MATLAB's space/hyphen sanitization. No forcing is evaluated by this work.
- Method-only or unregistered legacy diagnostics have explicit incompatibility records, including enstrophy methods and the non-callable legacy default-operation annotations. Working `energy_<component>` factories cover component energy. These exclusions do not remove any MATLAB API.
- Construction-only C++ plans resolve names to ordinals, topological dependency order and masks with zero C++ heap allocations. All new identities remain unavailable to existing numerical field/output planners, including ordinals beyond their 64-bit field mask.
- MATLAB-readable JSON, C++ metadata/contracts and the developer table are generated from the same catalog. No second scientific registry is introduced.

## Local verification

| Gate | Result |
| --- | --- |
| MATLAB R2025b catalog tests | All 6 passed; byte comparison of JSON, both C++ headers and generated developer table; exact legacy metadata; negative graph, metadata and configuration tests. Absolute v4 test paths avoid a startup-path collision with the other checkout. |
| Native C++ runtime regressions | 13 focused tests passed: catalog, observer adapter, field evaluation, observer output, observation occurrence, model output, standalone runner and affected architecture policies. |
| Final C++ catalog and field tests | 2 passed after final metadata and rejection assertions. All 666 contract plans resolve without heap allocation. |
| ASan and UBSan | Final catalog and field tests passed; local Apple sanitizer run has leak detection disabled. Hosted runtime sanitizer gate retains its configured Linux checks. |
| MATLAB Code Analyzer | 5 changed MATLAB files, zero blocking findings. Remaining findings concern allocation while generating static developer artifacts. |
| Source-only runtime export contract | Focused release-verification method passed. |
| Documentation | `docs:check` passed: 2026 files, 4145 routes, zero changes and zero validation failures. |
| Scope and whitespace | `git diff --check` passed; no MATLAB production, manifest, dependency, snapshot, generated website or v5 changes. |

## Hosted integration

The focused `Portable variable catalog` workflow regenerates and byte-compares the same committed artifacts independently on R2025b and R2026a. R2026a is not installed on this host; its required goal evidence comes from that workflow. Required branch checks remain integration gates. Optional Full CI is not an extra integration gate.
