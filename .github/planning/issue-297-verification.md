# Stratified QG runtime integration — issue 297

Base: v4 main `96ba5aa558ee63756ae071105a054ce2ec269f86`. Branch: `issue-297-stratified-qg-runtime`. The user authorized implementation, GitHub updates and integration. MATLAB backward compatibility is mandatory. The separate v5 checkout and released OceanKit snapshots are outside this work.

## Delivered behavior

- Complete MATLAB-authored `WVTransformStratifiedQG` graphs execute with one `[Nj,Nkl]` A0 family. The runtime shares the immutable authoritative modal record across numerical, state and output owners after independent restore verification. It preserves numerical matrices and the opaque `N2Function` persistence payload for MATLAB reload without evaluating that payload or solving an eigenproblem.
- Nine applicable stable forcing factories cover nonlinear advection, adaptive damping, fixed/narrow-band amplitudes, explicit antialiasing, beta PV advection, linear/quadratic bottom friction and vertical diffusivity. Dispatch is resolved through the existing typed registry. Vertical diffusivity preserves MATLAB's intermediate projection in `DzG * DzzG * eta`; bottom friction uses the bottom quadrature weight. The prepared F/G and horizontal operators retain their existing storage strategy.
- Full fields, surface fields, nonuniform-depth position sampling, linear/spline interpolation, XY drifters at fixed depths, rank-three XY tracers, moorings and dense output groups are supported. Full-grid horizontal tracer derivatives preserve high modes outside the retained velocity basis and handle even-grid Nyquist derivatives correctly.
- RK4, RK23 and RK78 agree with MATLAB. Tests cover explicit steps, CFL-selected RK4, CFL-derived default initial steps for RK23/RK78, forcing constraints, and passive observers in linear SQG. MATLAB's stored horizontal-mean A0 values remain unchanged in linear dynamics.
- Multi-file identities, independent group schedules, dense fields, create/replace/append, segmented restart and MATLAB model reopening pass. Linear SQG can restart from its stationary Eulerian A0 stream. Mooring samples always retain MATLAB's record cadence, including stationary linear fields.
- MATLAB SQG does not expose `w`: its supported rank-three tracer uses `WVTracer(...,isXYOnly=true)`. Default three-dimensional vertical tracer advection is not a working MATLAB SQG graph and C++ rejects it before mutation. Existing MATLAB behavior is unchanged.
- The shared forcing slice now has 96 rows: 78 supported and 18 intentionally incompatible. SQG adds 17 supported rows and 7 incompatibilities across its two antialias configurations. Every supported SQG row has RHS and continuation evidence; rejected rows have registry/preflight evidence. Catalog regeneration is deterministic.
- The only MATLAB production edit adds SQG metadata validation to the portable-request writer. Existing constant/BQG validation, transform constructors, required properties, readers and save behavior are preserved.

## Verification ledger

Successful gates were not repeated without a subsequent relevant change. Initial fixture mistakes (unsupported-transform sentinel, scalar tracer metadata mutation, explicit CFL options on an adaptive request) were corrected; affected methods subsequently passed.

| Gate | Result / evidence |
| --- | --- |
| Native Release C++ contracts | 35/35 pass; `/private/tmp/wvm-297-native-final-tests.log`. A later metrics/event-plan validation change passed affected forcing/field contracts and the MATLAB sampling probe. |
| SQG kernel MATLAB parity | All 3 `TestStratifiedQGCompiledKernel` methods pass, reference/native, profiles, odd/even grids, antialias settings and retained subsets; `/private/tmp/wvm-297-kernel-parity.log`. |
| SQG runtime MATLAB parity | All 8 `TestPortableStratifiedQG` methods pass across focused runs. Exact forcing pairs and compositions, fields, explicit/default/CFL integration, linear passive observers, output policies and transactional rejection; `/private/tmp/wvm-297-matlab-final-parity.log`, `/private/tmp/wvm-297-final-regressions.log`, `/private/tmp/wvm-297-sanitizer-and-final-gates.log`. Native prepared forcing and moving-field probes allocate no application memory. |
| Existing forcing and catalog | All 9 `TestPortableStableForcing` and 4 `TestPortableForcingCompatibility` methods pass, including exact catalog regeneration and constant/BQG append; `/private/tmp/wvm-297-matlab-final-parity.log`. |
| MATLAB backward compatibility / exports | All 6 `TestStratifiedModalRecord` and 5 `TestCompiledKernelIntegration` methods pass, including old MATLAB files and property-only saves. Four focused `TestPortableRuntimeCompatibility` methods pass: linear adaptive graphs, all constant request forms, BQG requests, BQG multi-file groups/policies; `/private/tmp/wvm-297-final-regressions.log`. |
| Sanitizers | ASan+UBSan kernel/scientific-record contracts pass. Five reference-provider MATLAB runtime methods pass using sanitized runner/probes: linear passive graphs, multi-file policies/restart, incompatible graphs, RK4/RK23/RK78 observers and sampling. `detect_leaks=0` on macOS; invalid memory/UB halt on error. `/private/tmp/wvm-297-asan-final-tests.log`, `/private/tmp/wvm-297-sanitizer-and-final-gates.log`. |
| GCC portability | New runtime library and probes compile under GCC 14; scientific-record and SQG-kernel contracts pass (2/2). The macOS CLI fails in Apple's `mach/message.h` SDK macros under GCC; Linux hosted GCC checks cover the CLI. `/private/tmp/wvm-297-gcc-build.log`, `/private/tmp/wvm-297-gcc-focused-tests.log`. |
| ATS source consumer | Rebuilt unchanged AlongTrackSimulator against this branch; 7/7 pass. `/private/tmp/wvm-297-ats-final-tests.log`. |
| Code Analyzer | MATLAB R2025b: 177 production files, 0 blocking findings. `/private/tmp/wvm-297-sanitizer-and-final-gates.log`. |
| Documentation / source scope | `docs:check` passes with zero added, removed or modified generated files. Source-only export inputs and updated scientific/runtime hashes checked; no website, package metadata, released snapshots or v5 changes. |

## Integration and remaining qualification

Publish through the required Smoke, Documentation and Code Analyzer checks, also diagnose failures in the C++ jobs. Optional full CI may run independently and is not an additional merge gate. After integration, close #297 and update #298/#306 with the shared-catalog handoff.

Issue #298 retains the broader complete-model qualification campaign: machine-readable cross-feature evidence, energy/enstrophy continuation, larger grids and longer segments, native platform coverage, lifecycle and retained-memory/runtime measurements. SQG forcing closures and separate event occurrences currently reconstruct independently; report their actual work and use measured evidence for further reuse/tuning. Issue #306 assembles the same typed slice into the full catalog. Hydrostatic model execution remains a later transform milestone.
