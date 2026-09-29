"""Synthetic integration fixtures for the tracked artifact policy guard."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import check_artifact_policy as guard
from artifact_policy import ArtifactPolicyError, build_baseline


INPUTS_PATH = '.github/artifact-inputs.json'
BASELINE_PATH = '.github/artifact-baseline.json'
HISTORICAL_PATH = '.github/ci-evidence/synthetic/history.log'
FIXTURE_PATH = 'fixtures/synthetic/input.cfg'
POLICY_REGISTRATION = {
    BASELINE_PATH: 'source-configuration',
    INPUTS_PATH: 'source-configuration',
}


class ArtifactGuardIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='wvm-artifact-guard-')
        self.root = Path(self.temporary.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Artifact Guard Fixture')
        self.git('config', 'user.email', 'artifact-fixture@example.invalid')

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *arguments):
        return subprocess.check_output(['git', '-C', str(self.root), *arguments], text=True).strip()

    def write(self, relative, content):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def commit(self, message):
        self.git('add', '-A')
        self.git('commit', '-q', '-m', message)
        return self.git('rev-parse', 'HEAD')

    def tracked(self):
        raw = subprocess.check_output(['git', '-C', str(self.root), 'ls-files', '-z'])
        return [path for path in raw.decode().split('\0') if path]

    def registry(self, extra=None):
        paths = dict(POLICY_REGISTRATION)
        paths[FIXTURE_PATH] = 'fixture'
        if extra:
            paths.update(extra)
        return {'schema': 'wvm-artifact-inputs-v1', 'paths': paths}

    def write_policy(self, baseline, registry=None):
        self.write(BASELINE_PATH, json.dumps(baseline, indent=2) + '\n')
        self.write(INPUTS_PATH, json.dumps(registry or self.registry(), indent=2) + '\n')

    def commit_pre_policy_history(self):
        self.write(HISTORICAL_PATH, 'retained historical output\n')
        self.write(FIXTURE_PATH, 'scientific input\n')
        return self.commit('history before policy bootstrap')

    def build_valid_bootstrap(self, base):
        baseline = build_baseline(self.root, [HISTORICAL_PATH])
        self.write_policy(baseline)
        self.git('add', BASELINE_PATH, INPUTS_PATH)
        with patch.object(guard, 'INITIAL_BASE_REVISION', base):
            errors = guard.validate(self.root, self.tracked(), base)
        return baseline, errors

    def test_initial_bootstrap_accepts_only_digests_found_at_the_recorded_base(self):
        base = self.commit_pre_policy_history()
        baseline, errors = self.build_valid_bootstrap(base)

        self.assertEqual(errors, [])
        self.assertEqual(baseline['entries'][0]['path'], HISTORICAL_PATH)

    def test_bootstrap_rejects_preexisting_output_omitted_from_registry_and_baseline(self):
        omitted = '.github/ci-evidence/synthetic/omitted.log'
        self.write(HISTORICAL_PATH, 'registered baseline output\n')
        self.write(omitted, 'pre-policy output\n')
        self.write(FIXTURE_PATH, 'scientific input\n')
        base = self.commit('history before policy bootstrap')
        baseline = build_baseline(self.root, [HISTORICAL_PATH])
        self.write_policy(baseline)
        self.git('add', BASELINE_PATH, INPUTS_PATH)

        with patch.object(guard, 'INITIAL_BASE_REVISION', base):
            errors = guard.validate(self.root, self.tracked(), base)

        self.assertIn(f'Initial artifact omitted without registration or retirement: {omitted}', errors)

    def test_bootstrap_rejects_fake_digest_and_missing_historical_source(self):
        base = self.commit_pre_policy_history()
        baseline = build_baseline(self.root, [HISTORICAL_PATH])
        baseline['entries'][0]['sha256'] = 'a' * 64

        with patch.object(guard, 'INITIAL_BASE_REVISION', base):
            digest_errors = guard.validate_history(self.root, baseline, base)

        missing_path = '.github/ci-evidence/synthetic/not-in-base.log'
        fake_source = {
            'schema': baseline['schema'],
            'entries': [{
                'path': missing_path,
                'sha256': hashlib.sha256(b'fabricated').hexdigest(),
                'role': 'historical-output',
            }],
            'retired': [],
        }
        with patch.object(guard, 'INITIAL_BASE_REVISION', base):
            source_errors = guard.validate_history(self.root, fake_source, base)

        self.assertTrue(any(HISTORICAL_PATH in error and 'unchanged historical content' in error
                            for error in digest_errors))
        self.assertTrue(any(missing_path in error and 'unchanged historical content' in error
                            for error in source_errors))

    def test_bootstrap_is_rejected_at_any_revision_other_than_the_recorded_initial_base(self):
        base = self.commit_pre_policy_history()
        baseline = build_baseline(self.root, [HISTORICAL_PATH])

        with patch.object(guard, 'INITIAL_BASE_REVISION', 'f' * 40):
            errors = guard.validate_history(self.root, baseline, base)

        self.assertIn('Artifact baseline bootstrap is allowed only at its recorded initial revision', errors)

    def test_registered_policy_documents_and_new_output_are_checked_by_exact_path(self):
        base = self.commit_pre_policy_history()
        _, errors = self.build_valid_bootstrap(base)
        self.assertEqual(errors, [])

        new_output = '.github/ci-evidence/synthetic/new-run.log'
        self.write(new_output, 'new raw output\n')
        self.git('add', new_output)
        with patch.object(guard, 'INITIAL_BASE_REVISION', base):
            errors = guard.validate(self.root, self.tracked(), base)

        self.assertIn(f'Unregistered tracked artifact: {new_output}', errors)
        self.assertNotIn(f'Unregistered tracked artifact: {BASELINE_PATH}', errors)
        self.assertNotIn(f'Unregistered tracked artifact: {INPUTS_PATH}', errors)

    def test_policy_json_files_require_explicit_source_configuration_roles(self):
        base = self.commit_pre_policy_history()
        baseline = build_baseline(self.root, [HISTORICAL_PATH])
        registry = {'schema': 'wvm-artifact-inputs-v1', 'paths': {FIXTURE_PATH: 'fixture'}}
        self.write_policy(baseline, registry)
        self.git('add', BASELINE_PATH, INPUTS_PATH)

        with patch.object(guard, 'INITIAL_BASE_REVISION', base):
            errors = guard.validate(self.root, self.tracked(), base)

        self.assertIn(f'Unregistered tracked artifact: {BASELINE_PATH}', errors)
        self.assertIn(f'Unregistered tracked artifact: {INPUTS_PATH}', errors)

    def test_registered_role_cannot_overlap_a_baseline_artifact(self):
        base = self.commit_pre_policy_history()
        baseline = build_baseline(self.root, [FIXTURE_PATH])
        self.write_policy(baseline, self.registry())
        self.git('add', BASELINE_PATH, INPUTS_PATH)

        with patch.object(guard, 'INITIAL_BASE_REVISION', base):
            with self.assertRaisesRegex(ArtifactPolicyError, 'Registered paths cannot also be baseline'):
                guard.validate(self.root, self.tracked(), base)

    def test_baseline_retirement_preserves_history_and_verifies_source_within_pr(self):
        self.write(HISTORICAL_PATH, 'retained historical output\n')
        self.write(FIXTURE_PATH, 'scientific input\n')
        initial_baseline = build_baseline(self.root, [HISTORICAL_PATH])
        self.write_policy(initial_baseline)
        base = self.commit('policy and active historical entry')

        self.write('docs/change.md', 'unrelated reviewed change\n')
        source_commit = self.commit('reviewed pre-deletion source')
        self.git('rm', '-q', HISTORICAL_PATH)
        old_entry = initial_baseline['entries'][0]
        retired = {
            'path': HISTORICAL_PATH,
            'sha256': old_entry['sha256'],
            'reason': 'Its published reference was removed.',
            'sourceCommit': source_commit,
        }
        retired_baseline = {'schema': initial_baseline['schema'], 'entries': [], 'retired': [retired]}
        self.write(BASELINE_PATH, json.dumps(retired_baseline, indent=2) + '\n')
        self.commit('retire historical output')

        errors = guard.validate_history(self.root, retired_baseline, base)

        self.assertEqual(errors, [])
        self.assertNotEqual(source_commit, base)

    def test_retirement_with_fake_digest_or_unrelated_source_revision_fails(self):
        self.write(HISTORICAL_PATH, 'retained historical output\n')
        initial_baseline = build_baseline(self.root, [HISTORICAL_PATH])
        self.write_policy(initial_baseline)
        base = self.commit('policy and active historical entry')
        self.write('docs/change.md', 'another reviewed change\n')
        source_commit = self.commit('source before deletion')

        def retired_baseline(digest, source):
            return {
                'schema': initial_baseline['schema'],
                'entries': [],
                'retired': [{
                    'path': HISTORICAL_PATH,
                    'sha256': digest,
                    'reason': 'Retirement fixture.',
                    'sourceCommit': source,
                }],
            }

        bad_digest = retired_baseline('b' * 64, source_commit)
        unrelated = retired_baseline(initial_baseline['entries'][0]['sha256'], 'f' * 40)

        self.assertTrue(guard.validate_history(self.root, bad_digest, base))
        self.assertTrue(guard.validate_history(self.root, unrelated, base))

    def test_pull_request_uses_merge_base_and_push_uses_its_declared_base(self):
        self.write('README.md', 'common ancestor\n')
        common = self.commit('common ancestor')
        self.git('checkout', '-q', '-b', 'pr-base')
        self.write('pr-only.txt', 'pull request base\n')
        pr_base = self.commit('pull request base')
        self.git('checkout', '-q', '-b', 'feature-head', common)
        self.write('head-only.txt', 'head change\n')
        head = self.commit('head')

        with patch.dict(os.environ, {
            'PR_BASE_SHA': pr_base,
            'HEAD_SHA': head,
            'PUSH_BASE_SHA': '',
        }):
            self.assertEqual(guard.comparison_base(self.root), common)

        with patch.dict(os.environ, {
            'PR_BASE_SHA': '',
            'HEAD_SHA': head,
            'PUSH_BASE_SHA': pr_base,
        }):
            self.assertEqual(guard.comparison_base(self.root), pr_base)

        with patch.dict(os.environ, {
            'PR_BASE_SHA': '',
            'HEAD_SHA': head,
            'PUSH_BASE_SHA': '0' * 40,
        }):
            self.assertEqual(guard.comparison_base(self.root), head)


if __name__ == '__main__':
    unittest.main()
