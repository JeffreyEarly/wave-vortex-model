"""Exercise real Git inventories, including rename/delete and >300 paths."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('route.py').resolve()


class ChangedPathTests(unittest.TestCase):
    def test_pr_inventory_excludes_base_branch_changes_and_retains_all_pr_commits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=CI fixture',
                    '-c', 'user.email=ci@example.invalid', '-c', 'commit.gpgsign=false',
                    *args], cwd=root, text=True).strip()
            git('init', '-q')
            (root / 'README.md').write_text('base\n')
            git('add', '.')
            git('commit', '-qm', 'common ancestor')
            base = git('rev-parse', 'HEAD')
            source = root / 'CompiledKernel/src/WVTransformBoussinesqKernel.cpp'
            source.parent.mkdir(parents=True)
            source.write_text('// base branch only\n')
            git('add', '.')
            git('commit', '-qm', 'base branch advances')
            base_tip = git('rev-parse', 'HEAD')
            git('checkout', '-qb', 'pull-request', base)
            for name in ['first.md', 'second.md']:
                (root / name).write_text('PR prose\n')
                git('add', '.')
                git('commit', '-qm', name)
            output = root / 'selection.json'
            subprocess.run(['python3', str(SCRIPT), '--base', base_tip, '--head', 'HEAD',
                            '--merge-base', '--output', str(output)],
                           cwd=root, check=True, capture_output=True)
            plan = json.loads(output.read_text())
            self.assertEqual(plan['paths'], ['first.md', 'second.md'])
            self.assertFalse(plan['cpp'])
            self.assertFalse(plan['packaging'])

    def test_inventory_is_not_api_truncated_and_includes_both_rename_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=CI fixture',
                    '-c', 'user.email=ci@example.invalid', '-c', 'commit.gpgsign=false',
                    *args], cwd=root, text=True).strip()
            git('init', '-q')
            old = root / 'CompiledKernel/src/WVTransformHydrostaticKernel.cpp'
            old.parent.mkdir(parents=True)
            old.write_text('// rename fixture\n')
            deleted = root / 'PortableRuntime/src/WVCheckpointWriter.cpp'
            deleted.parent.mkdir(parents=True)
            deleted.write_text('// deletion fixture\n')
            git('add', '.')
            git('commit', '-qm', 'base')
            base = git('rev-parse', 'HEAD')
            old.rename(old.with_name('WVTransformBoussinesqKernel.cpp'))
            deleted.unlink()
            for index in range(350):
                (root / f'notes-{index:03d}.md').write_text('prose\n')
            git('add', '.')
            git('commit', '-qm', 'representative changes')
            output = root / 'selection.json'
            subprocess.run(['python3', str(SCRIPT), '--base', base, '--head', 'HEAD',
                            '--output', str(output)], cwd=root, check=True, capture_output=True)
            plan = json.loads(output.read_text())
            self.assertEqual(len(plan['paths']), 353)
            self.assertIn('CompiledKernel/src/WVTransformHydrostaticKernel.cpp', plan['paths'])
            self.assertIn('CompiledKernel/src/WVTransformBoussinesqKernel.cpp', plan['paths'])
            self.assertIn('PortableRuntime/src/WVCheckpointWriter.cpp', plan['paths'])
            self.assertTrue(plan['persistence'])
            self.assertEqual(len(plan['families']), 5)


if __name__ == '__main__':
    unittest.main()
