import json
from pathlib import Path
import tempfile
import unittest
from artifacts import manifest, verify


class ArtifactTests(unittest.TestCase):
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
