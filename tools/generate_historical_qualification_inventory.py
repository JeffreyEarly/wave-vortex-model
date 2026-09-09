#!/usr/bin/env python3
"""Reproduce the reviewed historical inventory from clean recorded Git sources.

This is a maintenance command, not a CI dependency: shallow CI validates the
committed inventory against its independently pinned digest instead.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {
    'stratified-qg': ['TestPortableStratifiedQG', 'TestPortableStratifiedQGQualification',
                      'TestPortableStableForcing', 'TestPortableForcingCompatibility',
                      'TestCompiledKernelIntegration', 'TestStratifiedModalRecord'],
    'hydrostatic': ['TestPortableHydrostatic', 'TestPortableHydrostaticQualification',
                    'TestPortableStableForcing', 'TestPortableForcingCompatibility',
                    'TestCompiledKernelIntegration', 'TestStratifiedModalRecord',
                    'TestHydrostaticCompiledKernel', 'TestPortableStratifiedQGQualification'],
    'boussinesq': ['TestPortableBoussinesq', 'TestPortableBoussinesqQualification',
                   'TestPortableStableForcing', 'TestPortableForcingCompatibility',
                   'TestCompiledKernelIntegration', 'TestStratifiedModalRecord',
                   'TestBoussinesqCompiledKernel'],
}


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])


def test_methods(source, class_name):
    """These original classes have literal, unparameterized Test methods."""
    if re.search(r'\bTestParameter\b', source):
        raise ValueError('Parameterized source requires an explicit inventory derivation')
    result, active = [], False
    for line in source.splitlines():
        block = re.match(r'^    methods\s*\(([^)]*)\)', line)
        if block:
            active = bool(re.search(r'(^|,)\s*Test\s*(,|$)', block.group(1)))
        method = re.match(r'^        function\s+(\w+)\(', line)
        if active and method:
            result.append(class_name + '/' + method.group(1))
    if not result:
        raise ValueError('Missing independently derived test methods: ' + class_name)
    return result


def main():
    entries = []
    for family, classes in CLASSES.items():
        path = f'PortableRuntime/qualification/{family}-apple-silicon-v1.json'
        raw = (ROOT / path).read_bytes()
        report = json.loads(raw)
        assert report['workingTreeDirty'] is False
        commit = report['sourceCommit']
        entry = dict(family=family, sourceCommit=commit,
                     sourceTree=git('rev-parse', commit + '^{tree}').decode().strip(),
                     reportPath=path, reportSHA256=hashlib.sha256(raw).hexdigest(),
                     sources=[], testNames=[])
        for name in classes:
            source_path = 'UnitTests/' + name + '.m'
            source = git('show', commit + ':' + source_path)
            methods = test_methods(source.decode(), name)
            if family == 'hydrostatic' and name == 'TestPortableStratifiedQGQualification':
                methods = [name + '/lifecycleAndStorageRemainBounded']
            entry['sources'].append(dict(path=source_path,
                                         sha256=hashlib.sha256(source).hexdigest(), testNames=methods))
            entry['testNames'].extend(methods)
        # Check the original receipt only AFTER deriving the independent list.
        assert sorted(entry['testNames']) == sorted(row['name'] for row in report['tests'])
        assert len(entry['testNames']) == len(set(entry['testNames']))
        entries.append(entry)
    inventory = dict(schema='wave-vortex-historical-qualification-inventory-v1', schemaVersion=1,
                     scope='historical-workload', derivation='Literal Test methods from clean recorded source commits; no current class discovery or report-derived inventory.', entries=entries)
    destination = ROOT / 'PortableRuntime/qualification/historical-test-inventory-v1.json'
    destination.write_text(json.dumps(inventory, indent=2) + '\n')
    print('Reviewed inventory SHA256:', hashlib.sha256(destination.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
