#!/usr/bin/env python3
"""Check committed assembly provenance and executable CI fixture registration.

MATLAB owns scientific catalog regeneration and row semantics. This cheap gate
also runs for documentation-only changes, without repeating numerical tests.
"""
import hashlib
import json
from pathlib import Path
import re

from route import select

MATRIX = 'PortableRuntime/contracts/portable-compatibility-matrix-v1.json'


def local_file(root, relative):
    path = Path(relative)
    if path.is_absolute() or '..' in path.parts or not relative or '\\' in relative:
        raise ValueError(f'Invalid repository path: {relative}')
    resolved = (root / path).resolve()
    if not resolved.is_relative_to(root.resolve()) or not resolved.is_file():
        raise ValueError(f'Missing repository file: {relative}')
    return resolved


def check(root, catalog=None):
    root = Path(root)
    if catalog is None:
        catalog = json.loads((root / MATRIX).read_text())
    if (catalog['schema'], catalog['schemaVersion'], catalog['slice']) != (
            'portable-compatibility-matrix-v1', 1, 'standard'):
        raise ValueError('Unknown standard compatibility assembly')
    if catalog['readiness']['standardParityReady'] is not True or catalog['readiness']['decision'] != 'STANDARD-PORTABLE-PARITY':
        raise ValueError('Final standard parity requires the explicit STANDARD-PORTABLE-PARITY decision')
    source_ids = set()
    for source in catalog['sources']:
        if source['id'] in source_ids:
            raise ValueError(f'Duplicate source: {source["id"]}')
        source_ids.add(source['id'])
        actual = hashlib.sha256(local_file(root, source['path']).read_bytes()).hexdigest()
        if actual != source['sha256']:
            raise ValueError(f'Stale assembly input: {source["path"]}')
    complete_plan = select(['README.md'], complete=True)
    witnesses = {}
    for witness in catalog['witnesses']:
        if witness['id'] in witnesses:
            raise ValueError(f'Duplicate witness: {witness["id"]}')
        witnesses[witness['id']] = witness
        path = local_file(root, witness['path'])
        symbol = re.escape(witness['symbol'])
        source = path.read_text()
        if path.suffix == '.m':
            pattern = r'(?m)^\s*function\s+(?:\[[^\]]*\]\s*=\s*|\w+\s*=\s*)?' + symbol + r'\s*\('
            if witness['kind'] != 'matlab-authority' and path.stem not in complete_plan['matlabTests']:
                raise ValueError(f'MATLAB witness is not selected by complete CI: {path.stem}')
        else:
            pattern = r'\b' + symbol + r'\s*\('
            # A C++ witness must belong to a source compiled by a CMake target.
            cmake_sources = '\n'.join(p.read_text() for p in (root / 'PortableRuntime').rglob('CMakeLists.txt'))
            cmake_sources += '\n' + (root / 'CompiledKernel/CMakeLists.txt').read_text()
            if path.name not in cmake_sources:
                raise ValueError(f'C++ witness is not registered in CMake: {path.name}')
        if not re.search(pattern, source):
            raise ValueError(f'Unresolved witness: {witness["path"]}/{witness["symbol"]}')
    keys = set()
    for row in catalog['rows']:
        if row['id'] in keys:
            raise ValueError(f'Duplicate row: {row["id"]}')
        keys.add(row['id'])
        if row['sourceId'] not in source_ids:
            raise ValueError(f'Unresolved row source: {row["id"]}')
        if row['status'] not in {'supported', 'intentional-incompatibility', 'unqualified'}:
            raise ValueError(f'Unknown row status: {row["id"]}')
        if row['status'] == 'unqualified' and not row.get('issue', 0) > 0:
            raise ValueError(f'Untracked qualification gap: {row["id"]}')
        if row['status'] != 'unqualified' and not row['fixtures']:
            raise ValueError(f'Untested support/rejection: {row["id"]}')
        if any(identity not in witnesses for identity in row['fixtures']):
            raise ValueError(f'Unresolved row fixtures: {row["id"]}')
        for identity in row['fixtures']:
            if row['id'] not in witnesses[identity]['coverage']['rowIds']:
                raise ValueError(f'Fixture does not cover row: {identity}/{row["id"]}')
    for witness in witnesses.values():
        expected = {row['id'] for row in catalog['rows'] if witness['id'] in row['fixtures']}
        declared = witness['coverage']['rowIds']
        if len(declared) != len(set(declared)) or set(declared) != expected:
            raise ValueError(f'Contradictory fixture coverage: {witness["id"]}')
    if catalog['completion'] == 'complete' and any(r['status'] == 'unqualified' for r in catalog['rows']):
        raise ValueError('Incomplete qualification cannot declare complete coverage')
    if catalog['completion'] != 'complete' or any(r['status'] == 'unqualified' for r in catalog['rows']):
        raise ValueError('STANDARD-PORTABLE-PARITY requires zero unqualified rows')
    return len(keys), len(witnesses)


if __name__ == '__main__':
    rows, witnesses = check(Path(__file__).resolve().parents[2])
    print(f'Compatibility provenance and CI registration pass: {rows} rows, {witnesses} witnesses.')
