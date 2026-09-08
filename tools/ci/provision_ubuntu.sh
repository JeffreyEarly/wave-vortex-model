#!/usr/bin/env bash
# Bound network infrastructure work independently of numerical test execution.
set -euo pipefail
case "${1:-}" in netcdf|matlab) ;; *) echo 'Usage: provision_ubuntu.sh netcdf|matlab' >&2; exit 2 ;; esac
for source_file in /etc/apt/sources.list.d/ubuntu.sources /etc/apt/apt-mirrors.txt; do
    if [[ -f "$source_file" ]]; then
        sudo sed -i 's|http://azure.archive.ubuntu.com/ubuntu|https://archive.ubuntu.com/ubuntu|g' "$source_file"
    fi
done
# setup-matlab also invokes apt, so apply the same bounds to its subprocesses.
printf 'Acquire::Retries "1";\nAcquire::http::Timeout "20";\nAcquire::https::Timeout "20";\n' | sudo tee /etc/apt/apt.conf.d/80-wvm-ci-network >/dev/null
if [[ "$1" == netcdf ]]; then
    sudo apt-get update
    sudo apt-get install --yes libnetcdf-dev pkg-config
fi
