# PR #469 prerequisite qualification

Qualified source: `5e5f767c8d068e40dafc69237e4265e80ef13b58` (the final commit changes receipts only; binary embeds `6bfc9164e327482f19318f02cefc076755185489`). Candidate SHA-256: `0d6d8eeedbec4411939d2f8a9b0ceae42e6e615a6380905dfe78d5220141107e`. Control SHA-256: `7b301e5eef65afc18386596243f13f9dc0a9b719a25c45032bed2d49d1cf62b5`.

The production EddyTide integration and postprocessing had finished before this campaign. Agent builds and tests were paused. Two excluded warmup pairs and eight alternating measured pairs were run for each existing large composite profile. Source, binaries, and fixture hashes remained unchanged. Required CI for this source was already green (run 34643761502).

| Profile | Integration candidate/control geometric mean | Peak RSS ratio |
| --- | ---: | ---: |
| Constant nonhydrostatic composite, 256² ×129 | 0.988033 | 1.000019 |
| Variable hydrostatic composite, 256² ×129 | 0.992625 | 1.000030 |

The equal-profile paired bootstrap 95% interval is [0.981506, 0.998006], below the 1.03 regression gate. All scientific comparisons and the existing MATLAB-oracle checks passed. Exact native binary equality is not reproducible even for repeated executions of the same control; `../baseline-repeatability.json` records that finding. The driver uses the existing scientific tolerance (rtol 1e-10, atol 1e-12), records bitwise equality separately, and retains the original evidence.

## Corrected fixed metadata accounting

The original 368-byte prediction omitted reported string capacities, the integration system's moving-plan member, and two retained occurrence slots. The raw `summary.json` deliberately preserves its failed original 368-byte gate. An identical-path control/candidate audit removes unrelated path-string capacity changes and shows exactly **526 bytes** in both profiles:

- Five retained event-plan slots ×64 bytes = 320.
- Five empty configuration-string capacities ×22 bytes = 110 (the existing storage-accounting convention also counts inline string capacity).
- One output moving-plan member ×16 bytes = 16.
- Four retained occurrence geometry slots ×16 bytes = 64.
- One integration-system moving-plan member ×16 bytes = 16.

Total: 526 bytes. Output evaluation accounts for 510 bytes; the integration system accounts for 16. No scientific array capacity changes. The original campaign's variable-profile 718-byte difference includes 192 bytes of request/output path-string capacity differences; the equal-path audit removes all 192. This is a corrected metadata derivation, not a relaxation of the prohibition on new retained scientific volumes. `equal-path-memory-audit.json` records the independently measured category deltas.

Qualification therefore passes with the corrected fixed-metadata accounting. The raw protocol, samples, original failed summary, adjusted comparison driver, and memory audit are retained for review. This receipt qualifies PR #469 only; it does not qualify issue #470.
