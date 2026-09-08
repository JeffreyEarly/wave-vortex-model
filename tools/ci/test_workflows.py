"""Validate the dependency/gate wiring as well as the routing algorithm."""
import os
from pathlib import Path
import re
import unittest
import yaml
from route import select, FAMILY_TESTS, SHARED_TESTS

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = Path(os.environ.get('WVM_CI_WORKFLOW_TEST_DIR', ROOT / '.github/workflows'))


def workflow(name):
    # BaseLoader preserves GitHub's YAML 1.2 key "on" (YAML 1.1 makes it True).
    return yaml.load((WORKFLOWS / name).read_text(), Loader=yaml.BaseLoader)


class WorkflowContracts(unittest.TestCase):
    def test_gate_waits_for_every_selected_job_and_cannot_be_skipped(self):
        jobs = workflow('ci.yml')['jobs']
        gate = jobs['required-gate']
        self.assertEqual(gate['name'], 'Required / WaveVortexModel')
        self.assertEqual(gate['if'], 'always()')
        self.assertEqual(set(gate['needs']), {'route', 'repository', 'cpp-release', 'cpp-sanitized', 'matlab', 'matlab-sanitized', 'packages'})
        self.assertNotIn('continue-on-error', gate)
        self.assertIn('tools/ci/gate.py', gate['steps'][-1]['run'])
        for name in gate['needs']:
            self.assertNotIn('continue-on-error', jobs[name])
        for configuration in ['release', 'sanitized']:
            self.assertEqual(jobs['cpp-'+configuration]['with']['configuration'], configuration)
        self.assertIn('cpp-release', jobs['matlab']['needs'])
        self.assertNotIn('cpp-sanitized', jobs['matlab']['needs'])
        self.assertIn('matlab_matrix', jobs['matlab']['strategy']['matrix'])
        self.assertEqual(jobs['matlab-sanitized']['with']['configuration'], 'sanitized')

    def test_full_qualification_is_retained_outside_ordinary_prs(self):
        main = workflow('ci.yml')
        self.assertIn('schedule', main['on'])
        self.assertIn('complete', main['on']['workflow_dispatch']['inputs'])
        env = main['jobs']['route']['steps'][1]['env']
        self.assertIn("github.event_name == 'schedule'", env['COMPLETE'])
        extended = workflow('extended-ci.yml')
        self.assertNotIn('pull_request', extended['on'])
        self.assertEqual(set(extended['jobs']), {'full', 'exhaustive', 'optional'})
        for name in ['hydrostatic-kernel.yml', 'boussinesq-kernel.yml', 'sqg-qualification.yml']:
            triggers = workflow(name)['on']
            self.assertIn('workflow_dispatch', triggers)
            self.assertNotIn('pull_request', triggers)
            self.assertNotIn('push', triggers)

    def test_package_validation_stays_isolated_and_selected(self):
        package = workflow('release-verification.yml')
        self.assertIn('workflow_call', package['on'])
        self.assertEqual(set(package['jobs']), {'clean-install', 'exported-package'})
        exported = str(package['jobs']['exported-package']['steps'])
        self.assertIn('git clone --no-hardlinks', exported)
        self.assertIn('verifyWaveVortexModelPackage', exported)
        self.assertIn('$export_path/PortableRuntime', exported)
        jobs = workflow('ci.yml')['jobs']
        self.assertEqual(jobs['packages']['uses'], './.github/workflows/release-verification.yml')
        self.assertIn('packaging', jobs['packages']['if'])

    def test_only_infrastructure_setup_can_retry_or_continue_after_error(self):
        for name in ['ci.yml', 'ci-cpp.yml', 'ci-matlab.yml', 'extended-ci.yml', 'release-verification.yml',
                     'hydrostatic-kernel.yml', 'boussinesq-kernel.yml', 'sqg-qualification.yml']:
            for job in workflow(name)['jobs'].values():
                for step in job.get('steps', []):
                    if 'continue-on-error' in step:
                        self.assertEqual(step.get('uses'), 'matlab-actions/setup-matlab@v3')
                        self.assertEqual(step['id'], 'setup')
                    if step.get('uses') == 'matlab-actions/setup-matlab@v3':
                        self.assertEqual(step['timeout-minutes'], '5')
                    if step.get('id') == 'retry':
                        self.assertEqual(step['uses'], 'matlab-actions/setup-matlab@v3')
                        self.assertIn("steps.setup.outcome == 'failure'", step['if'])
                        self.assertIn('!cancelled()', step['if'])

    def test_legacy_required_names_depend_on_the_real_gate(self):
        jobs = workflow('ci.yml')['jobs']
        for name, label in [('smoke', 'Smoke'), ('documentation', 'Documentation'), ('analyzer', 'Code Analyzer')]:
            job = jobs['legacy-' + name]
            self.assertEqual(job['name'], label + ' / MATLAB R2025b')
            self.assertIn('required-gate', job['needs'])
            self.assertEqual(job['steps'][0]['run'], 'test "$RESULT" = success')

    def test_consolidation_preserves_each_existing_qualification_class(self):
        for family, function in [('hydrostatic', 'qualifyPortableHydrostatic'),
                                 ('boussinesq', 'qualifyPortableBoussinesq'),
                                 ('sqg', 'qualifyPortableStratifiedQG')]:
            source = (ROOT / 'tools' / (function + '.m')).read_text()
            declaration = re.search(r'classes = \[(.*?)\];', source).group(1)
            old_classes = set(re.findall(r'"(Test\w+)"', declaration))
            self.assertLessEqual(old_classes, set(FAMILY_TESTS[family] + SHARED_TESTS))
        plan = select(['PortableRuntime/src/anything.cpp'])
        self.assertIn('TestPortableVariableCatalog', plan['matlabTests'])
        self.assertIn('TestPortableDiagnostics', plan['matlabTests'])
        self.assertEqual(plan['releases'], ['R2025b', 'R2026a'])
        self.assertEqual(len(plan['deferredMethods']), 3)
        self.assertEqual(select(['README.md'], complete=True)['deferredMethods'], [])


if __name__ == '__main__':
    unittest.main()
