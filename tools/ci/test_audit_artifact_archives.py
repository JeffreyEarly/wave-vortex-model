"""Synthetic tests for the bounded compressed-artifact audit."""
import gzip
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import audit_artifact_archives as scanner


class ArchiveAuditTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="wvm-archive-audit-")
        self.root = Path(self.temporary.name) / "repo"
        self.root.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Archive Audit Fixture")
        self.git("config", "user.email", "archive-audit@example.invalid")
        self.candidate = "PortableRuntime/qualification/receipt.json"
        candidate_path = self.root / self.candidate
        candidate_path.parent.mkdir(parents=True)
        self.candidate_bytes = b'{"qualification":"passed"}\n'
        candidate_path.write_bytes(self.candidate_bytes)
        self.manifest = Path(self.temporary.name) / "candidates.json"
        self.manifest.write_text(json.dumps([self.candidate]) + "\n")

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True).strip()

    def add_archive_and_commit(self, relative, payload):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(gzip.compress(payload))
        self.git("add", self.candidate, relative)
        self.git("commit", "-q", "-m", "synthetic archive fixture")

    def test_reports_gzip_digest_and_path_references(self):
        digest = scanner.sha256(self.candidate_bytes)
        payload = f"{self.candidate} {digest}\n".encode()
        archive = ".github/ci-evidence/fixture/report.json.gz"
        self.add_archive_and_commit(archive, payload)

        result = scanner.audit(self.root, self.manifest)

        self.assertEqual(result["candidateCount"], 1)
        self.assertEqual(result["archiveCount"], 1)
        match = result["matches"][0]
        self.assertEqual(match["candidate"], self.candidate)
        self.assertEqual(match["archive"], archive)
        self.assertIn("repository-path", match["matches"])
        self.assertIn("sha256", match["matches"])
        self.assertEqual(result["unsupported"], [])

    def test_reports_archive_with_no_candidate_match(self):
        archive = "Benchmarks/results/reference/unrelated.json.gz"
        self.add_archive_and_commit(archive, b'{"note":"no candidate here"}\n')

        result = scanner.audit(self.root, self.manifest)

        self.assertEqual(result["matches"], [])
        self.assertEqual(result["unsupported"], [])
        self.assertEqual(result["archives"][0]["members"][0]["decompressedBytes"], len(b'{"note":"no candidate here"}\n'))

    def test_expansion_cap_is_reported_as_unsupported(self):
        archive = "evidence/oversized.log.gz"
        self.add_archive_and_commit(archive, b"0123456789abcdef")

        with patch.object(scanner, "MAX_MEMBER", 8):
            result = scanner.audit(self.root, self.manifest)

        self.assertEqual(len(result["unsupported"]), 1)
        self.assertEqual(result["unsupported"][0]["archive"], archive)
        self.assertIn("expansion cap exceeded", result["unsupported"][0]["error"])


if __name__ == "__main__":
    unittest.main()
