# MATLAB compiled evaluation lifecycle (#506)

Coordinator design and implementation ledger. The foundation is merged in PR #508; native active-demand planning is implemented in 3201952b. All six public constructors and consumers are integrated in `a8ab7a0d`; merged-main integration is `6c7095d7`. Focused public parity, restoration and consumer checks pass. Combined installed/export and release qualification remain gated on #507.

## Ownership and event boundaries

A compiled backend owns immutable configuration, one family engine, its borrowed field service and prepared operators. A scoped MATLAB event opens the field service's existing evaluator, with a native-owned copy of the current coefficient arrays made once when the event begins. Never retain an mxArray data pointer after its MEX call. An explicit monotonically increasing event token identifies the immutable native state. Time and storage addresses are validation facts, not the unchanged-state identity.

Nested MATLAB scopes join the current event. Their onCleanup callbacks close only the generation they own. Setters of t/t0/Ap/Am/A0 invalidate an active compiled event before mutation, including same-time assignments and in-place MATLAB indexed assignments. Prepared configuration setters reject mutation while a native owner holds a source-identity lease. This includes privately created adapters on otherwise MATLAB-default transforms. The final native owner releases the lock; MATLAB-only objects remain writable. Restart and restored models obtain fresh owner identity. A rejected/retried or dense-output state starts another event.

RHS scope must enclose forcing plus subsequent tracer and particle consumers. Output scope must enclose coincident destinations/sampling calls. Standalone public calls use fresh temporary scopes. MATLAB keeps its existing variable cache and published arrays; native dependency caches are scoped to the event. No scientific cache survives completion, although explicitly prepared workspaces may retain capacity.

## Shared producers and MATLAB callbacks

Use the field service as the sole native event owner. Do not nest its session inside the separate ordinary forcing-engine RHS scope. Its existing forcing diagnostic binding already shares raw nonlinear tendencies, physical fields, derivatives and reductions under the same producer ledger.

For the default built-in instance, exact native field names are Fu_nonlinear_advection, Fv_nonlinear_advection, Feta_nonlinear_advection; Boussinesq adds Fw_nonlinear_advection. QG uses Fqgpv_nonlinear_advection. Return these raw arrays to MATLAB's existing ordered spatial accumulation, then project the accumulated result once at the existing spatial-to-spectral boundary. Subsequent spectral and amplitude callbacks retain their established order. This does not require exposing private native cumulative-prefix coefficients or executing nonlinear advection twice.

Arbitrary MATLAB callbacks remain MATLAB code, and their supported transform calls use native primitives. Interception of a registered variable must identify its actual built-in operation instance/provenance; a familiar output name alone must never bypass a user replacement. Known component bindings must retain their exact masks and density reference. Custom masks/operations must use their declared supported primitive calls, not be relabeled as standard native components.

Raw derivative calls on arbitrary supplied arrays remain explicit primitives. Do not guess that an array is a cached state field from its address or elapsed time. Registered state derivatives and built-in forcing dependencies use their authoritative evaluator keys.

## Demand planning implementation

Ordinary `createPlan` prepares storage and must not be called during a live session. `createPlanForActiveEvaluation` explicitly extends demand between producer calls under the reuse policy. Both paths use the same authoritative dependency walk. The active path rejects reentrant execution and incompatible group/policy requests.

Arena entries have stable owners; extensions cannot resize assigned storage or invalidate a consumer view. Already prepared forcing storage is reused only for the same stage/policy signature. Density extensions preserve ready profiles, inverse maps and reference-specific results. Failed planning does not publish the candidate or discard prior cached values. The existing prepared-workload path remains unchanged. Native field, forcing and density incremental-demand tests pass.

## Qualification

Focused MEX tests already cover all-six scoped state ownership, nested queries, mutation poisoning, failure recovery and delayed cleanup. The initial public random Fourier test found an orientation error in the constant raw primitive, corrected with independent nonsymmetric direct-DFT oracles. Final public tests must run against the rebuilt shared module; older private analytic-fixture receipts are not substitutes.


Require one state validation/phase preparation per wave event, zero repeated identical producers, explicit state-copy bytes, no stale result publication after failures, and bounded live memory. Cover nonlinear plus damping, custom replacement operations and forcing order, nested scopes, mutation/retry/restart/dense output, tracers/particles, coincident outputs, density references and components. Performance qualification follows a frozen combined implementation; no benchmark runs are needed during interface development.

## Verification ledger, September 13 UTC qualification pass

- Native Release/AppleClang: complete 54-test suite passed (11.28 s), including shared active-demand, raw primitives, family kernels/runtime and standalone runner. No runtime sources changed afterward.
- Public review-fix batch: 11/11 MATLAB R2025b methods passed, covering all-family fields/primitives, vertical calculus, actual/initial density references, nonlinear plus adaptive damping, ordered forcing diagnostics, H tracer/particle/mooring/output integration, coefficient subclasses, registry invalidation and all-family restart/resolution/explicit-antialias factories.
- Native lease follow-up: 7/7 methods passed, including two owners sharing a MATLAB source, failed construction, configuration rejection before mutation, BT primitive parity and all-six scoped lifetime/failure recovery.
- Source-frozen bridge 6 build passed on `6c7095d7`; binary and complete native/MATLAB-client manifest bound in the validated build record. Documentation and current-selection metadata are outside this build inventory.
- Combined MATLAB adapter/build/rollback/source checks, installed/export checks and final source-linked portable/ATS evidence remain pending. Do not interpret focused tests as these remaining gates.

Raw local logs and CSVs are retained in `/private/tmp/wvm503/` until compact qualification receipts are archived. Existing #503/#504/#505 receipts retain their measured source identities.

Combined follow-up: all 48 MATLAB adapter methods pass across the initial session and four-method legacy-test repair. Native runtime and MATLAB production class sources are unchanged. Code Analyzer has zero blockers, with reviewed onCleanup/mixin false positives classified narrowly; two stale file-count assertions were repaired. Website generation/check passed (2,047 files, 4,187 routes). Compact evidence is in `.github/ci-evidence/issue-507-matlab-adapters/`.

Final portable forward integration passed all six family cases under both reference and native FFTW providers (252.65 s total). Fresh receipts were collected by the authoritative collector; prior executed receipts remain unchanged in the evidence archive.
