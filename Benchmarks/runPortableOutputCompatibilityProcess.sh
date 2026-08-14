#!/bin/sh
set -eu

if [ "$#" -ne 10 ]; then
    echo "usage: runPortableOutputCompatibilityProcess.sh CHECKPOINT MATLAB_FIRST MATLAB_SECOND RUNTIME_FIRST EXECUTABLE PHASE RSS STOP SAMPLER INTERVAL" >&2
    exit 2
fi

checkpoint=$1
matlab_first=$2
matlab_second=$3
runtime_first=$4
executable=$5
phase=$6
rss=$7
stop=$8
sampler=$9
shift 9
interval=$1

printf '%s\n' compatibility > "$phase"
WV_RUNTIME_CHECKPOINT_FIXTURE="$checkpoint" \
WV_MATLAB_MODEL_OUTPUT_FIXTURE="$matlab_first" \
WV_MATLAB_MODEL_OUTPUT_FIXTURE_SECOND="$matlab_second" \
WV_RUNTIME_MODEL_OUTPUT_EXPORT="$runtime_first" \
    "$executable" &
worker_pid=$!
/bin/sh "$sampler" "$worker_pid" "$phase" "$stop" "$rss" "$interval" &
sampler_pid=$!

status=0
wait "$worker_pid" || status=$?
: > "$stop"
wait "$sampler_pid" || true
exit "$status"
