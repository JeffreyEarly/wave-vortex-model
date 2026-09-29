"""Regression fixtures for routine CI selection and test dependency routing."""
import json
from pathlib import Path
import unittest

from route import select


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEPENDENCIES_PATH = Path(__file__).with_name('test_dependencies.json')


class RoutineSelectionTests(unittest.TestCase):
    def test_prose_has_no_matlab_phases_or_matrices(self):
        plan = select(['README.md'])

        self.assertFalse(plan['matlab'])
        self.assertFalse(plan['smoke'])
        self.assertFalse(plan['sanitized'])
        self.assertEqual(plan['releases'], [])
        self.assertEqual(plan['matlabShards'], [])
        self.assertEqual(plan['sanitizedShards'], [])

    def test_documentation_runs_matlab_documentation_without_smoke(self):
        plan = select(['Documentation/WebsiteDocumentation/users-guide/output.md'])

        self.assertTrue(plan['matlab'])
        self.assertTrue(plan['documentation'])
        self.assertFalse(plan['smoke'])
        self.assertFalse(plan['sanitized'])
        self.assertEqual(plan['releases'], ['R2025b'])
        self.assertEqual(plan['matlabTests'], [])
        self.assertEqual(plan['matlabShards'][0]['classes'], [])
        self.assertEqual(plan['sanitizedShards'], [])

    def test_complete_qualification_selects_both_releases(self):
        routine = select(['README.md'])
        complete = select(['README.md'], complete=True)

        self.assertEqual(routine['releases'], [])
        self.assertEqual(complete['releases'], ['R2025b', 'R2026a'])
        self.assertTrue(complete['matlab'])
        self.assertTrue(complete['smoke'])

    def test_registered_matlab_class_gets_only_its_class_and_smoke(self):
        plan = select(['UnitTests/TestVerticalCalculus.m'])

        self.assertEqual(plan['matlabTests'], ['TestVerticalCalculus'])
        self.assertTrue(plan['matlab'])
        self.assertTrue(plan['smoke'])
        self.assertFalse(plan['cpp'])
        self.assertFalse(plan['sanitized'])
        self.assertEqual(plan['sanitizedTests'], [])
        self.assertEqual(plan['sanitizedShards'], [])
        self.assertEqual(plan['releases'], ['R2025b'])

    def test_explicit_native_dependency_selects_the_class_for_sanitized_ci(self):
        plan = select(['UnitTests/TestPortableDiagnostics.m'])

        self.assertEqual(plan['matlabTests'], ['TestPortableDiagnostics'])
        self.assertEqual(plan['sanitizedTests'], ['TestPortableDiagnostics'])
        self.assertTrue(plan['cpp'])
        self.assertTrue(plan['sanitized'])
        self.assertEqual(plan['sanitizedShards'][0]['classes'], ['TestPortableDiagnostics'])

    def test_portable_prefix_does_not_imply_native_probe_dependency(self):
        plan = select(['UnitTests/TestPortableCompatibilityMatrix.m'])

        self.assertEqual(plan['matlabTests'], ['TestPortableCompatibilityMatrix'])
        self.assertFalse(plan['cpp'])
        self.assertFalse(plan['sanitized'])
        self.assertEqual(plan['sanitizedShards'], [])

    def test_unknown_test_class_retains_conservative_broad_fallback(self):
        plan = select(['UnitTests/TestNotYetRegistered.m'])

        self.assertEqual(set(plan['families']), {'constant', 'barotropic', 'sqg', 'hydrostatic', 'boussinesq'})
        self.assertIn('TestNotYetRegistered', plan['matlabTests'])
        self.assertTrue(plan['matlab'])
        self.assertTrue(plan['smoke'])
        self.assertTrue(plan['sanitized'])

    def test_workflow_path_is_conservative_unless_content_only_is_proven(self):
        path = '.github/workflows/ci.yml'
        conservative = select([path])
        content_only = select([path], content_only_workflows=[path])

        self.assertTrue(conservative['matlab'])
        self.assertTrue(conservative['cpp'])
        self.assertFalse(content_only['matlab'])
        self.assertFalse(content_only['smoke'])
        self.assertFalse(content_only['sanitized'])
        self.assertEqual(content_only['releases'], [])
        self.assertEqual(content_only['matlabShards'], [])
        self.assertEqual(content_only['sanitizedShards'], [])

    def test_content_only_classification_must_name_a_changed_workflow(self):
        with self.assertRaises(ValueError):
            select(['README.md'], content_only_workflows=['.github/workflows/ci.yml'])

    def test_dependency_registry_names_existing_formal_test_classes(self):
        registry = json.loads(DEPENDENCIES_PATH.read_text())
        registered = registry['classes']
        formal_classes = {path.stem for path in (REPOSITORY_ROOT / 'UnitTests').glob('Test*.m')}

        self.assertTrue(set(registered) <= formal_classes)
        self.assertTrue(all(type(value['nativeProbes']) is bool for value in registered.values()))

    def test_native_registry_records_probe_use_not_class_name_prefix(self):
        registry = json.loads(DEPENDENCIES_PATH.read_text())['classes']

        self.assertTrue(registry['TestPortableDiagnostics']['nativeProbes'])
        self.assertTrue(registry['TestStratifiedModalRecord']['nativeProbes'])
        self.assertFalse(registry['TestPortableCompatibilityMatrix']['nativeProbes'])
        self.assertFalse(registry['TestWVCompiledBackend']['nativeProbes'])
        self.assertFalse(registry['TestFocusedCISelection']['nativeProbes'])


class GateSelectionTests(unittest.TestCase):
    def test_gate_accepts_no_matlab_selection_without_matlab_evidence(self):
        from gate import validate

        plan = select(['README.md'], source_commit='abc123')
        jobs = {
            name: {'result': 'success' if required else 'skipped'}
            for name, required in {
                'route': True,
                'repository': True,
                'cpp-release': plan['cpp'],
                'cpp-sanitized': plan['cpp'],
                'matlab': plan['matlab'],
                'matlab-sanitized': plan['sanitized'],
                'packages': plan['packaging'],
            }.items()
        }

        self.assertTrue(validate(plan, jobs, []))

    def test_gate_rejects_matlab_execution_when_selection_has_no_matlab(self):
        from gate import validate

        plan = select(['README.md'], source_commit='abc123')
        jobs = {
            name: {'result': 'success' if required else 'skipped'}
            for name, required in {
                'route': True,
                'repository': True,
                'cpp-release': plan['cpp'],
                'cpp-sanitized': plan['cpp'],
                'matlab': plan['matlab'],
                'matlab-sanitized': plan['sanitized'],
                'packages': plan['packaging'],
            }.items()
        }
        jobs['matlab']['result'] = 'success'

        with self.assertRaises(ValueError):
            validate(plan, jobs, [])

    def test_gate_rejects_evidence_when_matlab_was_not_selected(self):
        from gate import validate

        plan = select(['README.md'], source_commit='abc123')
        jobs = {
            name: {'result': 'success' if required else 'skipped'}
            for name, required in {
                'route': True,
                'repository': True,
                'cpp-release': plan['cpp'],
                'cpp-sanitized': plan['cpp'],
                'matlab': plan['matlab'],
                'matlab-sanitized': plan['sanitized'],
                'packages': plan['packaging'],
            }.items()
        }
        report = {
            'schema': 'wvm-ci-matlab-v2',
            'sourceCommit': plan['sourceCommit'],
            'matlabRelease': 'R2025b',
            'configuration': 'release',
            'shard': 0,
        }

        with self.assertRaises(ValueError):
            validate(plan, jobs, [report])



def _gate_jobs(plan):
    selected = {
        'route': True,
        'repository': True,
        'cpp-release': plan['cpp'],
        'cpp-sanitized': plan['cpp'],
        'matlab': plan['matlab'],
        'matlab-sanitized': plan['sanitized'],
        'packages': plan['packaging'],
    }
    return {name: {'result': 'success' if required else 'skipped'} for name, required in selected.items()}


def _gate_reports(plan, smoke_by_release=None):
    smoke_by_release = smoke_by_release or {}
    identities = [
        (release, 'release', group)
        for release in plan['releases']
        for group in plan['matlabShards']
    ]
    if plan['sanitized']:
        identities.extend(('R2025b', 'sanitized', group) for group in plan['sanitizedShards'])
    reports = []
    for release, configuration, group in identities:
        classes = group['classes']
        shard = group['id']
        expects_smoke = configuration == 'release' and shard == 0 and plan['smoke']
        smoke = list(smoke_by_release.get(release, ['TestSmoke/baseline'])) if expects_smoke else []
        names = [name + '/method' for name in classes] + (smoke if expects_smoke else [])
        reports.append({
            'schema': 'wvm-ci-matlab-v2',
            'sourceCommit': plan['sourceCommit'],
            'matlabRelease': release,
            'configuration': configuration,
            'shard': shard,
            'passed': True,
            'requestedClasses': classes,
            'deferredMethods': plan['deferredMethods'],
            'excludedTags': plan['excludedTags'],
            'excludedClasses': [],
            'excludedTests': [],
            'expectedTests': names,
            'smokeExpectedTests': smoke,
            'phases': {
                'smoke': expects_smoke,
                'analyzer': configuration == 'release' and release == 'R2025b' and shard == 0 and plan['analyzer'],
                'documentation': configuration == 'release' and release == 'R2025b' and shard == 0 and plan['documentation'],
            },
            'tests': [{'name': name, 'passed': True, 'incomplete': False} for name in names],
        })
    return reports


class GateSmokeCoverageTests(unittest.TestCase):
    def test_complete_evidence_with_the_same_smoke_baseline_passes(self):
        from gate import validate

        plan = select(['README.md'], complete=True, source_commit='abc123')
        self.assertTrue(validate(plan, _gate_jobs(plan), _gate_reports(plan)))

    def test_gate_requires_reported_smoke_discovery_when_smoke_is_selected(self):
        from gate import validate

        plan = select(['UnitTests/TestVerticalCalculus.m'], source_commit='abc123')
        reports = _gate_reports(plan)
        smoke_report = next(report for report in reports if report['configuration'] == 'release')
        smoke_report['smokeExpectedTests'] = []

        with self.assertRaises(ValueError):
            validate(plan, _gate_jobs(plan), reports)

    def test_gate_requires_every_discovered_smoke_method_to_execute(self):
        from gate import validate

        plan = select(['UnitTests/TestVerticalCalculus.m'], source_commit='abc123')
        reports = _gate_reports(plan)
        smoke_report = next(report for report in reports if report['configuration'] == 'release')
        smoke_report['tests'] = [test for test in smoke_report['tests'] if test['name'] != 'TestSmoke/baseline']
        smoke_report['expectedTests'] = [name for name in smoke_report['expectedTests'] if name != 'TestSmoke/baseline']

        with self.assertRaises(ValueError):
            validate(plan, _gate_jobs(plan), reports)

    def test_smoke_baseline_must_match_between_complete_releases(self):
        from gate import validate

        plan = select(['UnitTests/TestVerticalCalculus.m'], complete=True, source_commit='abc123')
        reports = _gate_reports(plan, smoke_by_release={
            'R2025b': ['TestSmoke/baseline'],
            'R2026a': ['TestSmoke/changed'],
        })

        with self.assertRaises(ValueError):
            validate(plan, _gate_jobs(plan), reports)


class WorkflowClassificationTests(unittest.TestCase):
    def test_execution_signature_ignores_comments_and_trigger_changes(self):
        from route import workflow_execution

        base = """name: CI\non:\n  pull_request:\njobs:\n  check:\n    steps:\n      - run: python check.py\n"""
        trigger_changed = base.replace('pull_request:', 'push:')
        comment_changed = '# explanatory comment\n' + base
        dispatch_added = base.replace('on:\n  pull_request:', 'on:\n  workflow_dispatch: null\n  pull_request:')

        expected = workflow_execution(base)
        self.assertEqual(workflow_execution(trigger_changed), expected)
        self.assertEqual(workflow_execution(comment_changed), expected)
        self.assertEqual(workflow_execution(dispatch_added), expected)

    def test_execution_signature_detects_step_environment_and_workflow_call_changes(self):
        from route import workflow_execution

        base = """name: Reusable check\non:\n  workflow_call:\n    inputs:\n      mode:\n        required: true\njobs:\n  check:\n    steps:\n      - run: python check.py\n        env:\n          MODE: strict\n"""
        changed_step = base.replace('python check.py', 'python other.py')
        changed_environment = base.replace('MODE: strict', 'MODE: relaxed')
        changed_api = base.replace('required: true', 'required: false')
        dispatch = base.replace('workflow_call:', 'workflow_dispatch:').replace(
            '      mode:', '      complete:').replace('        required: true', '        type: boolean')

        expected = workflow_execution(base)
        self.assertNotEqual(workflow_execution(changed_step), expected)
        self.assertNotEqual(workflow_execution(changed_environment), expected)
        self.assertNotEqual(workflow_execution(changed_api), expected)
        self.assertNotEqual(workflow_execution(dispatch), expected)

    def test_duplicate_or_malformed_workflow_cannot_be_classified_content_only(self):
        from unittest.mock import patch
        from route import content_only_workflows

        path = '.github/workflows/ci.yml'
        valid = 'jobs:\n  check:\n    steps:\n      - run: python check.py\n'
        duplicate = 'jobs:\n  check: {}\n  check: {}\n'
        malformed = 'jobs: [\n'

        with patch('route.subprocess.check_output', side_effect=[valid, duplicate]):
            self.assertEqual(content_only_workflows('base', 'head', [path]), [])
        with patch('route.subprocess.check_output', side_effect=[valid, malformed]):
            self.assertEqual(content_only_workflows('base', 'head', [path]), [])

    def test_content_only_classification_requires_equal_execution(self):
        from unittest.mock import patch
        from route import content_only_workflows

        path = '.github/workflows/ci.yml'
        before = 'jobs:\n  check:\n    steps:\n      - run: python check.py\n'
        after = before.replace('python check.py', 'python other.py')

        with patch('route.subprocess.check_output', side_effect=[before, after]):
            self.assertEqual(content_only_workflows('base', 'head', [path]), [])

if __name__ == '__main__':
    unittest.main()
