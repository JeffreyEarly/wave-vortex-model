#!/bin/sh
set -eu

if test "$#" -ne 1; then
    printf '%s\n' "Usage: $0 OUTPUT_DIRECTORY" >&2
    exit 2
fi

output_root=$1
cache_root=${ISSUE152_CACHE_ROOT:-/private/tmp/issue152-overnight-cache}
pthread_executable=$cache_root/build/wv_issue152_pthreads
openmp_executable=$cache_root/providers/openmp/install/lib/wv_issue152_openmp
openmp_runtime=$cache_root/providers/openmp/install/lib/libwvissue137omp.dylib
threads=${ISSUE152_THREADS:-4}

test "$threads" -ge 1
test "$threads" -le 4
test -x "$pthread_executable"
test -x "$openmp_executable"
test -f "$openmp_runtime"
test ! -e "$output_root"
mkdir -p "$output_root"

for hydrostatic in 1 0; do
    case_name=nonhydro
    if test "$hydrostatic" = 1; then case_name=hydro; fi
    reference=$output_root/$case_name.ref

    "$pthread_executable" --Nx 128 --Ny 128 --Nz 33 --Nj 21 \
        --threads "$threads" --warmups 2 --samples 3 --hydrostatic "$hydrostatic" \
        --variant explicit --reference-output "$reference" \
        --output "$output_root/$case_name-pthreads-explicit.json"

    for variant in explicit fftwpp-implicit fftwpp-hybrid; do
        OMP_NUM_THREADS=$threads "$openmp_executable" --Nx 128 --Ny 128 --Nz 33 --Nj 21 \
            --threads "$threads" --warmups 2 --samples 3 --hydrostatic "$hydrostatic" \
            --variant "$variant" --reference-input "$reference" \
            --expected-openmp-runtime "$openmp_runtime" \
            --output "$output_root/$case_name-openmp-$variant.json"
    done
done

jq -s '.' "$output_root"/*.json > "$output_root/screening.json"
printf '%s\n' "$output_root/screening.json"
