"""Small source-policy tests; no scientific runs or recorded result fixtures."""
from pathlib import Path
import tempfile
import unittest

from checkRepositoryArtifacts import artifact_reason, removed_link_errors, violations


class ArtifactPolicyTests(unittest.TestCase):
    def test_rejects_outputs_even_when_compressed_or_markdown(self):
        for path in ["tools/study/results/summary.md", "Benchmarks/results/catalog.json",
                     "Documentation/Validation/Issue1/run.csv", "tools/run.log.gz",
                     "docs/assets/benchmarks/runtime.svg", "new-study/timings.json",
                     "PortableRuntime/tests/fixtures/run.log", "native.mexmaca64",
                     "tools/build/summary.md", "native.a", "native.dylib"]:
            with self.subTest(path=path):
                self.assertIsNotNone(artifact_reason(path))

    def test_preserves_source_dependencies_and_normal_documentation(self):
        for path in ["+WVInternal/solver.m", "AGENTS.md", "docs/users-guide/index.md",
                     "Benchmarks/schemas/benchmark-catalog-v1.schema.json",
                     "PortableRuntime/tests/fixtures/root-hydrostatic.nc",
                     "PortableRuntime/contracts/wave-vortex-run-request-v2.schema.json",
                     "UnitTests/ReferenceImplementations/data/buoyancy-oracle.csv",
                     "tools/scientific-validation-study/protocol.json"]:
            with self.subTest(path=path):
                self.assertIsNone(artifact_reason(path))

    def test_deletion_is_not_a_remaining_artifact(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "run.log").write_text("example")
            self.assertEqual(violations(root, ["run.log", "deleted.csv"]),
                             [("run.log", "recorded data, log, figure, or archive")])

    def test_deleted_local_links_are_reported_but_historical_urls_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "README.md").write_text("[data](results/run.csv) [history](https://example.com/results/run.csv)")
            self.assertEqual(removed_link_errors(root, ["README.md"], ["results/run.csv"]),
                             [("README.md", "link to removed file: results/run.csv")])


if __name__ == "__main__":
    unittest.main()
