# Prepared spectral execution

The v4 constant-stratification kernel prepares its FFT plans, scratch arenas and coefficient executor at construction. A workspace permits one synchronous active call. The default coefficient execution uses the calling thread and one persistent background thread; `WV_KERNEL_COEFFICIENT_WORKERS=1` selects serial execution. Every coefficient stage completes before FFT execution begins. Construction joins any workers already launched if a later launch fails, and destruction joins the retained workers.

The seventeen base plans and `4H+6R` numerical scratch bound are unchanged. Call `prepareScalarAdvection()` during setup when scalar advection is configured. It prepares one additional inverse plan, is idempotent, and can be retried after setup failure. The portable integration system already does this for its configured tracers. Ordinary RHS, RHS that returns velocity, and RHS that consumes prepared velocity retain their existing interfaces and shared particle/tracer velocity behavior.

Successful prepared native execution performs no application C++ allocations or thread launches. This covers forward/inverse transforms, F/G derivatives, the three RHS forms, and scalar advection with and without antialiasing. Failure reporting can allocate diagnostic strings. The deliberately simple reference FFT provider can allocate during execution and is not subject to the native allocation guarantee.

## Native FFTW ownership

`destroysInput=false` requires preservation for out-of-place execution. Native r2c and out-of-place DCT-I/DST-I plans request `FFTW_PRESERVE_INPUT`. Multidimensional c2r has no preserving algorithm in FFTW, so setup returns `unsupportedOperation`; callers must explicitly prepare destructive scratch and set `destroysInput=true`. The existing production inverse paths already use that scratch. No hidden preservation copy is retained.

In-place execution inherently overwrites shared storage and requires identical input/output pointers. This adapter supports in-place vertical real-to-real transforms with matching strides. Padded in-place horizontal transforms are rejected during setup. Out-of-place execution rejects identical pointers and partially overlapping addressed spans before entering FFTW. Positive strides, supported ranks, span arithmetic and declared buffer capacities are checked during setup. A failed setup leaves any existing output plan unchanged.

Planning buffers and raw plans have RAII ownership immediately after acquisition. All plan destruction, including cleanup after a wrapper allocation failure, takes the same mutex as planning. Lifetime plan counters include raw plans, so partial construction is visible and must balance.

These choices follow FFTW's [planner flags](https://www.fftw.org/fftw3_doc/Planner-Flags.html) and [thread safety](https://www.fftw.org/fftw3_doc/Thread-safety.html) contracts.

## Storage accounting

`kernelManagementBytes` includes the executor object and its retained `std::thread` vector capacity. Descriptor storage, scratch capacity, engine storage and plan wrapper storage remain separately reported. `persistentBytes` sums the known retained C++ storage. FFTW's internal plan storage and the thread runtime's heap bookkeeping, stacks and operating-system resources are opaque; these totals are lower bounds, not RSS or a complete process-memory bound. The native allocation test counts application `new`/`new[]`, including aligned allocation, and does not interpose FFTW/libc internal allocation.

## Verification

Run the portable tests with `tools/compiled-kernel/run_contract_tests.sh`. To include the native ownership and allocation tests, configure the same CMake project with the installed FFTW prefix:

```sh
cmake -S tools/compiled-kernel -B /tmp/wvm-kernel-tests \
  -DCMAKE_BUILD_TYPE=Release -DWV_KERNEL_FFTW_ROOT=/path/to/fftw-prefix
cmake --build /tmp/wvm-kernel-tests --parallel
ctest --test-dir /tmp/wvm-kernel-tests --output-on-failure
```

`TestWVPreparedModeExecutor` tests repeated serial/parallel partitions, exceptions, partial worker startup and allocation/thread-launch counts. `TestWVNativeFFTWOwnership` links the real FFTW library through test-only acquisition wrappers. It injects planning-buffer, raw-plan and wrapper failures, sweeps kernel application allocations, checks serialized planning/destruction, and compares even/odd hydrostatic/nonhydrostatic numerical results and immutable inputs. Production code contains no FFTW fault-injection hooks.

Issue [#356](https://github.com/JeffreyEarly/wave-vortex-model/issues/356) tracks this change. The task verification ledger is in `.github/planning/issue-356-verification.md`.
