#!/usr/bin/env python3
"""Cheap source-boundary and tracked-artifact checks, independent of MATLAB."""
import json
from pathlib import Path
import re
import subprocess

paths = subprocess.check_output(['git', 'ls-files', '-z']).decode().rstrip('\0').split('\0')
for name in paths:
    path = Path(name)
    if re.search(r'(^|/)(\.compiled-backend-cache|build)/|\.mex[a-z0-9]*$|\.(a|o|dylib)$|fftw-3\.3\.11\.tar\.gz$', name):
        raise SystemExit(f'Tracked build product: {name}')
    if path.is_file() and name.startswith(('CompiledKernel/include/', 'CompiledKernel/src/')):
        if re.search(r'#include\s*[<"](?:mex|matrix|matlab|fftw|netcdf)', path.read_text()):
            raise SystemExit(f'Forbidden core dependency: {name}')
    if path.is_file() and name.startswith('.github/ci-evidence/') and path.suffix == '.json':
        json.loads(path.read_text())
subprocess.run(['git', 'diff', '--check'], check=True)
subprocess.run(['python3', 'tools/ci/check_compatibility_matrix.py'], check=True)
print('Repository boundaries and tracked artifacts pass.')
