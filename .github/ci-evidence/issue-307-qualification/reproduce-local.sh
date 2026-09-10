#!/bin/sh
set -eu
wvm_root=$(git rev-parse --show-toplevel)
ats_root=$(dirname "$wvm_root")/AlongTrackSimulator
evidence="$wvm_root/.github/ci-evidence/issue-307-qualification"
ats_build=/private/tmp/wvm307-ats-build
native_build=/private/tmp/wvm-v4-audit-runtime
execution_commit=$(git rev-parse HEAD)
mkdir -p "$evidence/ats" "$evidence/lifecycle"
cmake -S "$ats_root" -B "$ats_build" -DCMAKE_BUILD_TYPE=Release -DALONGTRACK_BUILD_WAVEVORTEX_EXTENSION=ON -DALONGTRACK_WAVEVORTEX_SOURCE_DIR="$wvm_root" -DALONGTRACK_WARNINGS_AS_ERRORS=ON -DWV_ENABLE_ACCELERATE=OFF -DBUILD_TESTING=ON > "$evidence/ats/configure.log" 2>&1
cmake --build "$ats_build" --parallel 4 > "$evidence/ats/build.log" 2>&1
ctest --test-dir "$ats_build" --output-on-failure --output-junit "$evidence/ats/tests.xml" > "$evidence/ats/tests.log" 2>&1
cmake --build "$native_build" --target WVHydrostaticLifecycleProbe WVBoussinesqLifecycleProbe --parallel 4 > "$evidence/lifecycle/build.log" 2>&1
"$native_build/WVHydrostaticLifecycleProbe" /private/tmp/wvm305-performance/hydrostatic-source.nc "$evidence/lifecycle/hydrostatic.json" native-fftw > "$evidence/lifecycle/hydrostatic.log" 2>&1
"$native_build/WVBoussinesqLifecycleProbe" /private/tmp/wvm305-performance/boussinesq-source.nc "$evidence/lifecycle/boussinesq.json" native-fftw > "$evidence/lifecycle/boussinesq.log" 2>&1
# Run only after coordinating an idle host; baseline/candidate must remain frozen.
python3 "$evidence/measure-process-memory.py" --baseline /private/tmp/wvm391-density-output-baseline/wave-vortex-run --candidate "$native_build/wave-vortex-run" --fixtures /private/tmp/wvm305-performance --work /private/tmp/wvm307-process-memory --output "$evidence/process-memory" > "$evidence/process-memory.log" 2>&1
python3 "$evidence/collect-local-evidence.py" --execution-source-commit "$execution_commit"
