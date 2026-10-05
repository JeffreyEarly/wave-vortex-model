"""Keep published-asset registry maintenance out of scientific CI."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from diff_content import ARTIFACT_INPUTS, published_asset_only_registry_change
from route import FAMILIES
from test_gate import evidence

ROUTE = Path(__file__).with_name('route.py').resolve()
GATE = Path(__file__).with_name('gate.py').resolve()
ASSET = 'docs/assets/branding/icon.svg'
SOURCE_ASSET = 'Documentation/WebsiteDocumentation/assets/branding/icon.svg'


def registry(paths, **extra):
    return json.dumps(dict(schema='wvm-artifact-inputs-v1', paths=paths, **extra))


class PublishedAssetContentTests(unittest.TestCase):
    def test_asset_additions_removals_renames_and_formatting_are_safe(self):
        fixed = {ARTIFACT_INPUTS: 'source-configuration'}
        cases = [
            (fixed, dict(fixed, **{ASSET: 'published-asset'})),
            (dict(fixed, **{ASSET: 'published-asset'}), fixed),
            ({ASSET: 'published-asset'}, {SOURCE_ASSET: 'published-asset'}),
            (fixed, fixed),
        ]
        for before, after in cases:
            with self.subTest(before=before, after=after):
                self.assertTrue(published_asset_only_registry_change(registry(before), registry(after)))
        before = registry(dict(fixed, **{ASSET: 'published-asset'}))
        self.assertTrue(published_asset_only_registry_change(before, json.dumps(json.loads(before), indent=4)))

    def test_non_asset_changes_and_role_reclassifications_are_conservative(self):
        cases = [
            ({}, {'CompiledKernel/source-selection.json': 'source-configuration'}),
            ({'fixture.json': 'fixture'}, {}),
            ({ASSET: 'fixture'}, {ASSET: 'published-asset'}),
            ({ASSET: 'published-asset'}, {ASSET: 'contract'}),
            ({}, {ASSET: 'published-asset', 'fixture.json': 'fixture'}),
        ]
        for before, after in cases:
            with self.subTest(before=before, after=after):
                self.assertFalse(published_asset_only_registry_change(registry(before), registry(after)))

    def test_missing_malformed_duplicate_and_unknown_registry_content_is_conservative(self):
        valid = registry({ARTIFACT_INPUTS: 'source-configuration'})
        cases = [None, '', '{', 'null', '[]',
                 '{"schema":"wvm-artifact-inputs-v1","paths":[]}',
                 '{"schema":"other","paths":{}}',
                 registry({}, unknown=True),
                 registry({ASSET: 'unknown-role'}),
                 registry({ASSET: []}),
                 registry({'.': 'published-asset'}),
                 registry({'../outside.svg': 'published-asset'}),
                 registry({'docs//icon.svg': 'published-asset'}),
                 registry({'docs/invalid\0.svg': 'published-asset'}),
                 '{"schema":"wvm-artifact-inputs-v1","paths":{},"paths":{}}',
                 '{"schema":"wvm-artifact-inputs-v1","paths":{"icon.svg":"fixture","icon.svg":"published-asset"}}']
        for malformed in cases:
            with self.subTest(content=malformed):
                self.assertFalse(published_asset_only_registry_change(valid, malformed))
                self.assertFalse(published_asset_only_registry_change(malformed, valid))


class PublishedAssetGitRoutingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='wvm-ci-published-assets-')
        self.root = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)
        self.git('init', '-q')
        self.write(ARTIFACT_INPUTS, registry({ARTIFACT_INPUTS: 'source-configuration'}))
        self.base = self.commit('base')

    def git(self, *args):
        return subprocess.check_output(['git', '-c', 'user.name=CI fixture',
            '-c', 'user.email=ci@example.invalid', '-c', 'commit.gpgsign=false',
            *args], cwd=self.root, text=True).strip()

    def write(self, path, content):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(content)

    def commit(self, message):
        self.git('add', '-A')
        self.git('commit', '-qm', message)
        return self.git('rev-parse', 'HEAD')

    def add_branding(self):
        paths = {ARTIFACT_INPUTS: 'source-configuration', ASSET: 'published-asset', SOURCE_ASSET: 'published-asset'}
        self.write(ARTIFACT_INPUTS, registry(paths))
        for path in (ASSET, SOURCE_ASSET):
            self.write(path, '<svg xmlns="http://www.w3.org/2000/svg"/>\n')

    def selection(self, *extra, use_diff=True):
        output = self.root / '.git/selection.json'
        if use_diff:
            arguments = ['--base', self.base, '--head', 'HEAD']
        else:
            inventory = self.root / '.git/paths.json'
            inventory.write_text(json.dumps([ARTIFACT_INPUTS, ASSET, SOURCE_ASSET]))
            arguments = ['--paths-json', str(inventory)]
        subprocess.run([sys.executable, '-B', str(ROUTE), *arguments, *extra, '--output', str(output)],
                       cwd=self.root, check=True, capture_output=True, text=True)
        return json.loads(output.read_text())

    def gate(self, plan, jobs=None):
        default_jobs, reports = evidence(plan)
        self.write('.git/selection.json', json.dumps(plan))
        self.write('.git/jobs.json', json.dumps(default_jobs if jobs is None else jobs))
        report_root = self.root / '.git/reports'
        report_root.mkdir(exist_ok=True)
        for index, report in enumerate(reports):
            self.write(f'.git/reports/matlab-{index}.json', json.dumps(report))
        return subprocess.run([sys.executable, '-B', str(GATE),
            '--selection', str(self.root / '.git/selection.json'),
            '--jobs', str(self.root / '.git/jobs.json'), '--reports', str(report_root)],
            cwd=self.root, capture_output=True, text=True)

    def test_branding_and_registry_select_documentation_with_required_repository_checks(self):
        self.add_branding()
        self.commit('add branding')
        plan = self.selection()
        self.assertEqual(plan['paths'], sorted([ARTIFACT_INPUTS, ASSET, SOURCE_ASSET]))
        self.assertTrue(plan['documentation'])
        self.assertTrue(plan['matlab'])
        for flag in ('cpp', 'sanitized', 'smoke', 'packaging', 'analyzer', 'persistence', 'matlabCore'):
            self.assertFalse(plan[flag], flag)
        self.assertEqual(plan['matlabTests'], [])
        self.assertEqual(plan['matlabShards'][0]['classes'], [])
        self.assertIn('published-asset registrations only', '\n'.join(plan['reasons']))
        result = self.gate(plan)
        self.assertEqual(result.returncode, 0, result.stderr)
        jobs, _ = evidence(plan)
        jobs['repository']['result'] = 'skipped'
        self.assertNotEqual(self.gate(plan, jobs).returncode, 0)

    def test_registry_only_formatting_does_not_run_matlab(self):
        self.write(ARTIFACT_INPUTS, json.dumps(json.loads((self.root / ARTIFACT_INPUTS).read_text()), indent=4))
        self.commit('format registry')
        plan = self.selection()
        self.assertFalse(plan['matlab'])
        self.assertFalse(plan['cpp'])
        result = self.gate(plan)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_other_scientific_changes_keep_their_selected_family(self):
        self.add_branding()
        self.write('CompiledKernel/src/WVTransformHydrostaticKernel.cpp', '// scientific change\n')
        self.commit('branding and hydrostatic change')
        plan = self.selection()
        self.assertEqual(plan['families'], ['hydrostatic'])
        self.assertTrue(plan['cpp'])
        self.assertTrue(plan['sanitized'])
        self.assertIn('TestPortableHydrostaticQualification', plan['matlabTests'])

    def test_paths_only_and_complete_runs_keep_conservative_coverage(self):
        self.add_branding()
        self.commit('add branding')
        for plan in (self.selection(use_diff=False), self.selection('--complete')):
            self.assertEqual(set(plan['families']), set(FAMILIES))
            self.assertTrue(plan['cpp'])
            self.assertTrue(plan['packaging'])

    def test_gate_rechecks_committed_registry_content_and_rejects_a_forged_reduction(self):
        self.add_branding()
        self.commit('add branding')
        narrow = self.selection()
        content = json.loads((self.root / ARTIFACT_INPUTS).read_text())
        content['paths'][ASSET] = 'contract'
        self.write(ARTIFACT_INPUTS, json.dumps(content))
        head = self.commit('change registration role')
        broad = self.selection()
        self.assertEqual(set(broad['families']), set(FAMILIES))
        self.assertTrue(broad['packaging'])
        forged = copy.deepcopy(narrow)
        forged['sourceCommit'] = forged['diffHead'] = head
        result = self.gate(forged)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Selection is incomplete', result.stderr)


if __name__ == '__main__':
    unittest.main()
