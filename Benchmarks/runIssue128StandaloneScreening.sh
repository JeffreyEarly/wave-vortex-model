#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_root=${1:-/private/tmp/issue128-standalone-screening}
pthread_executable=${ISSUE128_PTHREAD_EXECUTABLE:-/private/tmp/issue128-standalone-build/wv_issue128_pthreads}
openmp_root=${ISSUE128_OPENMP_PROVIDER_ROOT:-/private/tmp/issue128-native-cache/providers/native-neon-openmp-872739bfc5992370/install}
openmp_executable=${ISSUE128_OPENMP_EXECUTABLE:-$openmp_root/lib/wv_issue128_openmp}
openmp_runtime=$openmp_root/lib/libwvissue137omp.dylib
thread_counts=${ISSUE128_THREAD_COUNTS:-"1 4 8 16"}
warmups=${ISSUE128_SCREENING_WARMUPS:-2}
samples=${ISSUE128_SCREENING_SAMPLES:-3}
nx=${ISSUE128_NX:-128}
ny=${ISSUE128_NY:-128}
nz=${ISSUE128_NZ:-33}
nj=${ISSUE128_NJ:-21}

test ! -e "$output_root"
mkdir -p "$output_root"
test -x "$pthread_executable"
test -x "$openmp_executable"
test -f "$openmp_runtime"

run_pthreads() {
    hydrostatic=$1
    seed=$2
    threads=$3
    reference_option=$4
    reference_path=$5
    output_path=$6
    (
        cd "$output_root"
        "$pthread_executable" \
            --Nx "$nx" --Ny "$ny" --Nz "$nz" --Nj "$nj" \
            --hydrostatic "$hydrostatic" --seed "$seed" \
            --threads "$threads" --warmups "$warmups" --samples "$samples" \
            --variant explicit "$reference_option" "$reference_path" --output "$output_path"
    )
}

run_openmp() {
    variant=$1
    hydrostatic=$2
    seed=$3
    threads=$4
    reference_path=$5
    output_path=$6
    (
        cd "$output_root"
        "$openmp_executable" \
            --Nx "$nx" --Ny "$ny" --Nz "$nz" --Nj "$nj" \
            --hydrostatic "$hydrostatic" --seed "$seed" \
            --threads "$threads" --warmups "$warmups" --samples "$samples" \
            --variant "$variant" --reference-input "$reference_path" \
            --expected-openmp-runtime "$openmp_runtime" --output "$output_path"
    )
}

for case_name in hydrostatic nonhydrostatic; do
    if test "$case_name" = hydrostatic; then
        hydrostatic=true
        seed=128389
    else
        hydrostatic=false
        seed=128289
    fi
    reference_path=$output_root/$case_name.ref
    first=true
    rotation=0
    for threads in $thread_counts; do
        if test "$first" = true; then
            reference_option=--reference-output
            first=false
        else
            reference_option=--reference-input
        fi
        run_pthreads "$hydrostatic" "$seed" "$threads" "$reference_option" "$reference_path" "$output_root/$case_name-pthreads-t$threads.json"
        case $rotation in
            0) variants="explicit fftwpp-implicit fftwpp-hybrid" ;;
            1) variants="fftwpp-implicit fftwpp-hybrid explicit" ;;
            2) variants="fftwpp-hybrid explicit fftwpp-implicit" ;;
        esac
        for variant in $variants; do
            run_openmp "$variant" "$hydrostatic" "$seed" "$threads" "$reference_path" "$output_root/$case_name-${variant}-t$threads.json"
        done
        rotation=$(( (rotation + 1) % 3 ))
    done
done

jq -s '.' "$output_root"/*.json > "$output_root/screening.json"
shasum -a 256 "$pthread_executable" "$openmp_executable" > "$output_root/executable-sha256.txt"
printf '%s\n' "$output_root/screening.json"
