#!/usr/bin/env python3
"""Package/validate portable probes with exact source and configuration identity."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

PROBES = ('wave-vortex-run', 'WVForwardIntegrationProbe', 'WVStableForcingDump', 'WVStratifiedQGFieldDump',
          'WVStratifiedQGLifecycleProbe', 'WVHydrostaticLifecycleProbe',
          'WVBoussinesqLifecycleProbe', 'WVStratifiedModalDump',
          'WVStratifiedQGKernelDump', 'WVHydrostaticKernelDump',
          'WVBoussinesqKernelDump', 'WVDiagnosticFieldDump', 'WVNoMotionProfileDump', 'WVNoMotionRecoveryDump',
          'WVDensityEventDump',
          'WVKernelDescriptorDump', 'WVBarotropicQGFixtureDump',
          'WVBarotropicQGToleranceDump', 'WVBarotropicQGForcingDump')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def manifest(directory, source, configuration):
    files = {p.name: digest(p) for p in sorted(directory.iterdir())
             if p.is_file() and p.name != 'manifest.json'}
    if 'wave-vortex-run' not in files:
        raise ValueError('Artifact has no wave-vortex-run executable')
    return dict(schema='wvm-ci-binaries-v1', sourceCommit=source,
                configuration=configuration, files=files)


def verify(directory, source, configuration):
    expected = json.loads((directory / 'manifest.json').read_text())
    actual = manifest(directory, source, configuration)
    if actual != expected:
        raise ValueError('Binary artifact source/configuration/content does not match this checkout')
    for name in actual['files']:
        (directory / name).chmod(0o755)
    return actual


def pack(build, directory, source, configuration):
    # CTest executables stay in the build job. MATLAB needs only these probes.
    for name in PROBES:
        path = build / 'bin' / name
        if not path.is_file() or not path.stat().st_mode & 0o111:
            raise ValueError(f'Missing executable probe: {name}')
    directory.mkdir(parents=True, exist_ok=False)
    for name in PROBES:
        shutil.copy2(build / 'bin' / name, directory / name)
    result = manifest(directory, source, configuration)
    (directory / 'manifest.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('pack', 'verify'))
    parser.add_argument('--directory', required=True, type=Path)
    parser.add_argument('--build', type=Path)
    parser.add_argument('--configuration', required=True, choices=('release', 'sanitized'))
    args = parser.parse_args()
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    if args.mode == 'pack':
        if not args.build:
            parser.error('--build is required to package artifacts')
        result = pack(args.build, args.directory, source, args.configuration)
    else:
        result = verify(args.directory, source, args.configuration)
    print(f"Verified {len(result['files'])} binaries for {source}/{args.configuration}")


if __name__ == '__main__':
    main()
