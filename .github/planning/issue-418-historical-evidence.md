# Issue 418: historical qualification inventory

## Change and authority

The stratified QG, hydrostatic, and Boussinesq qualification validators now distinguish original historical workloads from validation against the current test inventory. Their existing strict numerical, lifecycle, continuation, provider, and catalog checks remain in place. Current mode is the default and requires every current test; its classification is `current-inventory-only` with `currentReadiness=false`, because these validators do not independently establish source or execution freshness. Relabeling a source commit cannot confer readiness.

Historical mode is explicit (`evidenceScope="historical"`) and returns `historical-workload` with `currentReadiness=false`. Its independent manifest was derived from literal test declarations in the original clean Git source commits, before comparison with the original reports. The manifest includes source tree and file digests and original report digests. Its reviewed SHA256 is pinned in validator code: `da12f55d18401c52c0c5937d779e7e332fc2b6f13b44cb4cb693652697b068fc`. The maintenance exporter requires the original Git history; hosted validation uses the committed manifest and requires no history fetch.

Historical input must exactly equal the immutable original artifact, or an explicitly supported reference-only / reference contracts-only projection computed from that original artifact. Projections are never derived from caller-supplied results. The original complete artifact must first contain every independently derived original test and no failure or incomplete result. Source commits, numerical results, workload definitions, elapsed times, catalog identities, and artifact digests in the three original reports are unchanged. Historical acceptance is not a claim of current scientific qualification or source compatibility.

The three existing family evidence classes are restored to the corresponding required CI selections, and a new shared regression class is included in complete/relevant selections. Five-second scheduling estimates for these four structural classes are identified as local estimates, independently of the older hosted scheduling baseline.

## Focused verification

- MATLAB R2026a: all 17 evidence methods passed across the initial batch and one corrected-method rerun. The initial batch passed 16 and exposed a new test fixture typo (`duration` instead of an existing field); the corrected mutation uses `elapsedSeconds` and passed. No production issue was hidden by the correction.
- Following review, the changed readiness method passed again, including a synthetic full current inventory with a relabeled source commit that remains explicitly not current-ready.
- Code Analyzer: zero findings across all eight touched MATLAB files. Initial local-variable/property shadow warnings in the new test were corrected; the final new test and helper analyzers are retained.
- CI routing/policy: 43 focused Python tests passed. The routing regression checks family and complete selections, MATLAB/sanitized lists, and exactly one shard assignment.
- Documentation check: 2,026 files and 4,145 routes, zero failures, no generated page differences. No canonical API documentation was changed.
- Original report bytes were compared with the branch base and their pinned digests; all three are unchanged. Repository checks and whitespace checks pass.

No trajectory campaign, performance benchmark, full MATLAB suite, or C++ production build was run for this evidence-classification repair. Retained local logs and their original/normalized digests are in [the verification receipt](../ci-evidence/issue-418-historical-evidence/verification.json). The logs preserve the initial failed fixture and corrected reruns.
