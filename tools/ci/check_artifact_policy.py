#!/usr/bin/env python3
"""Enforce finite historical outputs and explicit scientific-input registration."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

from artifact_policy import check_repository, parse_baseline, validate_baseline_transition

BASELINE = '.github/artifact-baseline.json'
REGISTRY = '.github/artifact-inputs.json'
# Merged PR541: the immutable base of this policy's one-time bootstrap.
INITIAL_BASE_REVISION = '4d0c04a99177d7ca74cc9ffba240546ed3b410d6'
HISTORICAL_ROOTS = ('.github/ci-evidence/', 'PortableRuntime/qualification/',
                    'Benchmarks/results/', 'docs/benchmarks/')
OUTPUT_SUFFIXES = {'.json', '.log', '.out', '.err', '.mat', '.nc', '.csv', '.tsv',
                   '.xml', '.gz', '.zip', '.h5', '.hdf5', '.bin', '.dat', '.txt', '.text', '.jsonl',
                   '.png', '.pdf', '.jpg', '.jpeg', '.webp', '.eps', '.fig', '.svg', '.gif', '.mp4'}


def artifact_paths(paths):
    return sorted(path for path in paths if path.startswith(HISTORICAL_ROOTS)
                  or Path(path).suffix.lower() in OUTPUT_SUFFIXES)


def git_bytes(root, revision, path):
    result = subprocess.run(['git', 'show', f'{revision}:{path}'], cwd=root, capture_output=True)
    return result.stdout if result.returncode == 0 else None


def ancestor(root, older, newer):
    return subprocess.run(['git', 'merge-base', '--is-ancestor', older, newer],
                          cwd=root, capture_output=True).returncode == 0


def validate_history(root, baseline, base):
    old = git_bytes(root, base, BASELINE)
    entries, retired = parse_baseline(baseline)
    errors = []
    previous = json.loads(old) if old is not None else None
    previous_retired = parse_baseline(previous)[1] if previous is not None else {}
    if previous is None:
        if base != INITIAL_BASE_REVISION:
            return ['Artifact baseline bootstrap is allowed only at its recorded initial revision']
        # Every initial historical entry must already exist unchanged in Git.
        for path, record in entries.items():
            content = git_bytes(root, base, path)
            if content is None or hashlib.sha256(content).hexdigest() != record['sha256']:
                errors.append(f'Bootstrap entry is not unchanged historical content: {path}')
    verified_sources = set()
    for path, record in retired.items():
        if path in previous_retired:
            continue
        source = record['sourceCommit']
        if not ancestor(root, source, 'HEAD'):
            errors.append(f'Retirement source is not a reachable pre-deletion revision: {path}')
            continue
        content = git_bytes(root, source, path)
        original = git_bytes(root, base, path)
        if (content is None or content != original
                or hashlib.sha256(content).hexdigest() != record['sha256']):
            errors.append(f'Retirement does not match its immutable Git source: {path}')
        else:
            verified_sources.add(source)
    if previous is not None:
        errors.extend(validate_baseline_transition(previous, baseline, base, verified_sources=verified_sources))
    return errors


def comparison_base(root):
    pr_base = os.getenv('PR_BASE_SHA', '')
    if pr_base:
        head = os.environ['HEAD_SHA']
        return subprocess.check_output(['git', 'merge-base', pr_base, head], cwd=root, text=True).strip()
    push_base = os.getenv('PUSH_BASE_SHA', '')
    if push_base and push_base != '0' * 40:
        return push_base
    return subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()


def validate(root, paths, base):
    registry = json.loads((root / REGISTRY).read_text())
    if set(registry) != {'schema', 'paths'} or registry['schema'] != 'wvm-artifact-inputs-v1':
        raise ValueError('Unsupported artifact input registry')
    registered = registry['paths']
    baseline = json.loads((root / BASELINE).read_text())
    # Registered assets (including non-output extensions) must remain real files.
    missing = sorted(set(registered) - set(paths))
    errors = [f'Registered input is no longer tracked: {path}' for path in missing]
    errors.extend(f'Registered input is missing: {path}' for path in registered if not (root / path).is_file())
    governed = sorted(set(artifact_paths(paths)) | (set(registered) & set(paths)))
    errors.extend(check_repository(root, governed, registered, baseline))
    if git_bytes(root, base, BASELINE) is None:
        old_paths = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', '-z', base], cwd=root).decode().rstrip('\0').split('\0')
        entries, retired = parse_baseline(baseline)
        omitted = set(artifact_paths(old_paths)) - set(registered) - set(entries) - set(retired)
        errors.extend(f'Initial artifact omitted without registration or retirement: {path}' for path in omitted)
    errors.extend(validate_history(root, baseline, base))
    return sorted(set(errors))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base')
    args = parser.parse_args()
    root = Path.cwd()
    paths = subprocess.check_output(['git', 'ls-files', '-z']).decode().rstrip('\0').split('\0')
    errors = validate(root, paths, args.base or comparison_base(root))
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'Artifact policy passed: {len(artifact_paths(paths))} tracked artifacts; finite historical baseline verified.')


if __name__ == '__main__':
    main()
