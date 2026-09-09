#!/usr/bin/env bash
# Bound network infrastructure work independently of numerical test execution.
set -euo pipefail
case "${1:-}" in netcdf|matlab|build) ;; *) echo 'Usage: provision_ubuntu.sh netcdf|matlab|build' >&2; exit 2 ;; esac
# CI needs Ubuntu packages only. Disable the runner's unused Chrome repository
# before either our apt calls or setup-matlab refreshes package indexes.
for source_file in /etc/apt/sources.list.d/google-chrome*.list /etc/apt/sources.list.d/google-chrome*.sources; do
    if [[ -f "$source_file" ]]; then
        sudo mv "$source_file" "$source_file.disabled"
    fi
done
for source_file in /etc/apt/sources.list.d/ubuntu.sources /etc/apt/apt-mirrors.txt; do
    if [[ -f "$source_file" ]]; then
        sudo sed -i 's|http://azure.archive.ubuntu.com/ubuntu|https://archive.ubuntu.com/ubuntu|g' "$source_file"
    fi
done
# setup-matlab also invokes apt, so apply the same bounds to its subprocesses.
printf 'Acquire::Retries "1";\nAcquire::http::Timeout "20";\nAcquire::https::Timeout "20";\n' | sudo tee /etc/apt/apt.conf.d/80-wvm-ci-network >/dev/null
if [[ "$1" == netcdf || "$1" == build ]]; then
    sudo apt-get update
    packages=(libnetcdf-dev pkg-config)
    if [[ "$1" == build ]]; then packages+=(ccache); fi
    sudo apt-get install --yes "${packages[@]}"
fi
