#!/usr/bin/env bash

set -uo pipefail

failure=0

if ! git diff --check; then
    failure=1
fi

repository_status="$(git status --porcelain=v1 --untracked-files=all)"
if [[ -n "${repository_status}" ]]; then
    printf 'Unexpected tracked or untracked source paths:\n%s\n' "${repository_status}"
    failure=1
fi

artifact_paths="$(find . -path './.git' -prune -o -type f \( \
    -name '*.nc' -o \
    -name '*.mat' -o \
    -name '*.asv' -o \
    -name '*.prof' -o \
    -name '*.profile' -o \
    -name 'junit*.xml' -o \
    -name 'test-results*.xml' -o \
    -path './Benchmarks/results/runs/*' -o \
    -path '*/profile-results/*' -o \
    -path '*/profiling-output/*' -o \
    -path '*/test-results/*' -o \
    -path '*/TestResults/*' \
\) -print | sort | grep -Fvx \
    -e './tools/portable-runtime/fixtures/root-hydrostatic.nc' \
    -e './tools/portable-runtime/fixtures/root-nonhydrostatic.nc' \
    -e './tools/portable-runtime/fixtures/time-series-hydrostatic.nc' \
    -e './tools/portable-runtime/fixtures/time-series-nonhydrostatic.nc' || true)"

if [[ -n "${artifact_paths}" ]]; then
    printf 'Unexpected generated artifacts:\n%s\n' "${artifact_paths}"
    failure=1
fi

if (( failure != 0 )); then
    printf 'The source checkout is not clean.\n'
    exit 1
fi

printf 'The source checkout is clean.\n'
