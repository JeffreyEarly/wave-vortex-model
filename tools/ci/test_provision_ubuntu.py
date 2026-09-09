"""Exercise dependency setup with an isolated APT tree and harmless sudo shim."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name('provision_ubuntu.sh')


class UbuntuProvisioning(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.apt = self.root / 'apt'
        self.sources = self.apt / 'sources.list.d'
        self.sources.mkdir(parents=True)
        (self.apt / 'apt.conf.d').mkdir()
        self.log = self.root / 'commands.log'
        # Rewrite only the system directory for a sandboxed execution of the
        # production script. No host configuration or network is accessed.
        self.script = self.root / 'provision.sh'
        self.script.write_text(SCRIPT.read_text().replace('/etc/apt/', str(self.apt) + '/'))
        shim = self.root / 'sudo'
        shim.write_text('''#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >> "$WVM_TEST_COMMAND_LOG"
case "$1" in
    sed) exit 0 ;;
    tee) cat > "$2" ;;
    apt-get)
        # Emulate the observed index failure if any Chrome source is active.
        for source in "$WVM_TEST_APT"/sources.list.d/google-chrome*.{list,sources}; do
            if [[ -f "$source" ]]; then exit 100; fi
        done
        if [[ "$2" == "${WVM_TEST_FAIL_APT:-}" ]]; then exit 100; fi
        ;;
    *) "$@" ;;
esac
''')
        shim.chmod(0o755)
        self.environment = dict(os.environ, PATH=str(self.root) + os.pathsep + os.environ['PATH'],
                                WVM_TEST_COMMAND_LOG=str(self.log), WVM_TEST_APT=str(self.apt))

    def run_provision(self, mode):
        return subprocess.run(['bash', str(self.script), mode], env=self.environment,
                              capture_output=True, text=True)

    def test_unused_chrome_sources_are_disabled_for_every_setup_mode(self):
        for mode in ('build', 'netcdf', 'matlab'):
            with self.subTest(mode=mode):
                chrome_names = ('google-chrome.list', 'google-chrome-stable.list',
                                'google-chrome.sources', 'google-chrome-stable.sources')
                for name in chrome_names:
                    (self.sources / name).write_text('Chrome repository\n')
                for name in ('ubuntu.sources', 'microsoft-prod.list'):
                    (self.sources / name).write_text('unrelated repository\n')
                self.assertEqual(self.run_provision(mode).returncode, 0)
                for name in chrome_names:
                    self.assertFalse((self.sources / name).exists())
                    self.assertEqual((self.sources / (name + '.disabled')).read_text(), 'Chrome repository\n')
                for name in ('ubuntu.sources', 'microsoft-prod.list'):
                    self.assertEqual((self.sources / name).read_text(), 'unrelated repository\n')
        self.assertEqual((self.apt / 'apt.conf.d/80-wvm-ci-network').read_text(),
                         'Acquire::Retries "1";\nAcquire::http::Timeout "20";\nAcquire::https::Timeout "20";\n')

    def test_no_chrome_source_is_required_and_package_failures_remain_fatal(self):
        for mode, packages in (('build', 'libnetcdf-dev pkg-config ccache'),
                               ('netcdf', 'libnetcdf-dev pkg-config')):
            with self.subTest(mode=mode):
                self.log.write_text('')
                self.assertEqual(self.run_provision(mode).returncode, 0)
                self.assertEqual([line for line in self.log.read_text().splitlines() if line.startswith('apt-get')],
                                 ['apt-get update', 'apt-get install --yes ' + packages])
        for command in ('update', 'install'):
            with self.subTest(failure=command):
                self.environment['WVM_TEST_FAIL_APT'] = command
                self.log.write_text('')
                self.assertEqual(self.run_provision('build').returncode, 100)
                if command == 'update':
                    self.assertNotIn('apt-get install', self.log.read_text())


if __name__ == '__main__':
    unittest.main()
