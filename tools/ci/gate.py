#!/usr/bin/env python3
"""Fail closed unless each selected job and its exact-revision evidence passed."""
import argparse
import json
from pathlib import Path
from route import select


def validate(plan, jobs, reports):
    expected = select(plan['paths'], complete=plan['complete'], migration=plan['migration'],
                      source_commit=plan['sourceCommit'])
    if plan != expected:
        raise ValueError('Selection is incomplete or differs from the current routing policy')
    selected = {'route': True, 'repository': True, 'cpp-release': plan['cpp'], 'cpp-sanitized': plan['cpp'], 'matlab': True,
                'matlab-sanitized': plan['cpp'], 'packages': plan['packaging']}
    for name, required in selected.items():
        result = jobs.get(name, {}).get('result')
        allowed = {'success'} if required else {'skipped'}
        if result not in allowed:
            raise ValueError(f'{name}: expected {sorted(allowed)}, got {result!r}')
    expected_reports = [(release, 'release') for release in plan['releases']]
    if plan['cpp']:
        expected_reports.append(('R2025b', 'sanitized'))
    by_identity = {}
    for report in reports:
        identity = (report.get('matlabRelease'), report.get('configuration'))
        if identity in by_identity:
            raise ValueError(f'Duplicate MATLAB report: {identity}')
        by_identity[identity] = report
    if set(by_identity) != set(expected_reports):
        raise ValueError('Missing or unexpected MATLAB release/configuration evidence')
    for identity, report in by_identity.items():
        release, configuration = identity
        tests = plan['matlabTests'] if configuration == 'release' else plan['sanitizedTests']
        if report.get('schema') != 'wvm-ci-matlab-v1' or report.get('sourceCommit') != plan['sourceCommit']:
            raise ValueError(f'{identity}: stale or malformed MATLAB evidence')
        if report.get('requestedClasses') != tests or report.get('deferredMethods') != plan['deferredMethods']:
            raise ValueError(f'{identity}: requested coverage differs from selection')
        if report.get('passed') is not True:
            raise ValueError(f'{identity}: validation did not pass')
        phases = report.get('phases', {})
        expected_phases = {'smoke': configuration == 'release',
                           'analyzer': configuration == 'release' and release == 'R2025b' and plan['analyzer'],
                           'documentation': configuration == 'release' and release == 'R2025b' and plan['documentation']}
        if any(phases.get(key) is not value for key, value in expected_phases.items()):
            raise ValueError(f'{identity}: missing selected MATLAB phase')
        actual_tests = report.get('tests', [])
        if isinstance(actual_tests, dict):
            actual_tests = [actual_tests]
        names = [test.get('name', '') for test in actual_tests]
        if len(names) != len(set(names)):
            raise ValueError(f'{identity}: tests were duplicated')
        if names != report.get('expectedTests'):
            raise ValueError(f'{identity}: discovered test methods are missing from the results')
        for name in tests:
            if not any(test_name.startswith(name + '/') for test_name in names):
                raise ValueError(f'{identity}: no executed tests for {name}')
        if any(test.get('passed') is not True or test.get('incomplete') is not False for test in actual_tests):
            raise ValueError(f'{identity}: failed or incomplete numerical tests')
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--selection', required=True, type=Path)
    parser.add_argument('--jobs', required=True, type=Path)
    parser.add_argument('--reports', required=True, type=Path)
    args = parser.parse_args()
    reports = [json.loads(path.read_text()) for path in sorted(args.reports.rglob('matlab-*.json'))]
    validate(json.loads(args.selection.read_text()), json.loads(args.jobs.read_text()), reports)
    print('All selected CI jobs and exact-revision MATLAB evidence passed.')


if __name__ == '__main__':
    main()
