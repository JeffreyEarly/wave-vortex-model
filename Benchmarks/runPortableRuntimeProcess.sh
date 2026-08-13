#!/bin/sh
set -eu

if [ "$#" -ne 12 ]; then
    echo "usage: runPortableRuntimeProcess.sh RUNNER INPUT OUTPUT REPORT PHASE RSS STOP SAMPLER DT STEPS THREADS INTERVAL" >&2
    exit 2
fi

runner=$1
input=$2
output=$3
report=$4
phase=$5
rss=$6
stop=$7
sampler=$8
delta_t=$9
shift 9
steps=$1
threads=$2
interval=$3

printf '%s\n' startup > "$phase"
"$runner" "$input" "$output" --delta-t "$delta_t" --steps "$steps" --fft-provider native-fftw --threads "$threads" --report "$report" --phase-file "$phase" &
runner_pid=$!
/bin/sh "$sampler" "$runner_pid" "$phase" "$stop" "$rss" "$interval" &
sampler_pid=$!

status=0
wait "$runner_pid" || status=$?
: > "$stop"
wait "$sampler_pid" || true
exit "$status"
