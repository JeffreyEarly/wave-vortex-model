import json
from pathlib import Path
import tempfile
import unittest
from artifacts import manifest, verify, pack, PROBES


class ArtifactTests(unittest.TestCase):
    def test_pack_requires_probes_and_omits_build_only_test_executables(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            build = root / 'build'
            (build / 'bin').mkdir(parents=True)
            for name in (*PROBES, 'UnusedCTestExecutable'):
                path = build / 'bin' / name
                path.write_text(name)
                path.chmod(0o755)
            pack(build, root/'bundle', 'revision', 'sanitized')
            result = verify(root/'bundle', 'revision', 'sanitized')
            self.assertNotIn('UnusedCTestExecutable', result['files'])
            (build/'bin'/'WVHydrostaticLifecycleProbe').unlink()
            with self.assertRaisesRegex(ValueError, 'Missing executable probe'):
                pack(build, root/'incomplete', 'revision', 'sanitized')

    def test_rejects_changed_content_source_and_configuration(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root/'wave-vortex-run').write_text('probe')
            (root/'manifest.json').write_text(json.dumps(manifest(root, 'source-a', 'release')))
            verify(root, 'source-a', 'release')
            for source, configuration in [('source-b', 'release'), ('source-a', 'sanitized')]:
                with self.assertRaises(ValueError):
                    verify(root, source, configuration)
            (root/'wave-vortex-run').write_text('different probe')
            with self.assertRaises(ValueError):
                verify(root, 'source-a', 'release')


if __name__ == '__main__':
    unittest.main()
