import json
from pathlib import Path
import tempfile
import unittest

from audit_artifact_candidates import audit, sha256


class CandidateAuditTests(unittest.TestCase):
    def test_reports_candidate_identity_and_external_structured_text_references(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            candidate_dir = root / "PortableRuntime/qualification/forward-integration-evidence-v1"
            candidate_dir.mkdir(parents=True)
            first_content = b'{"case":"first"}\n'
            second_content = b'{"case":"second"}\n'
            first_hash = sha256(first_content)
            second_hash = sha256(second_content)
            first = f"PortableRuntime/qualification/forward-integration-evidence-v1/first-{first_hash}.json"
            second = f"PortableRuntime/qualification/forward-integration-evidence-v1/second-{second_hash}.json"
            (root / first).write_bytes(first_content)
            (root / second).write_bytes(second_content)

            source_manifest = root / "PortableRuntime/source-selection.json"
            source_manifest.write_text(json.dumps({"inputPath": first, "artifactDigest": second_hash}) + "\n")
            note = root / "notes.md"
            note.write_text(f"Historical receipt: {first}\n")
            reader = root / "tools/audit.py"
            reader.parent.mkdir(parents=True)
            reader.write_text(
                'evidence = Path("PortableRuntime/qualification")\n'
                'paths = evidence.glob("forward-integration-evidence-v1/*.json")\n'
            )

            tracked = [first, second, "PortableRuntime/source-selection.json", "notes.md", "tools/audit.py"]
            report = audit(root, [first, second], tracked, "a" * 40, "b" * 64)

        self.assertEqual(report["sourceCommit"], "a" * 40)
        self.assertEqual(report["candidateManifestSHA256"], "b" * 64)
        self.assertEqual(report["candidateCount"], 2)
        by_path = {item["path"]: item for item in report["candidates"]}
        self.assertEqual(by_path[first]["sha256"], first_hash)
        self.assertEqual(by_path[first]["bytes"], len(first_content))
        self.assertEqual(by_path[second]["sha256"], second_hash)

        refs = report["structuredReferences"]
        self.assertTrue(any(row["candidate"] == first and row["sourcePath"] == "PortableRuntime/source-selection.json"
                            and row["kind"] == "path-value" for row in refs))
        self.assertTrue(any(row["candidate"] == second and row["sourcePath"] == "PortableRuntime/source-selection.json"
                            and row["kind"] == "digest-value" for row in refs))
        self.assertTrue(any(row["candidate"] == first and row["sourcePath"] == "notes.md"
                            for row in report["textReferences"]))
        self.assertTrue(any(row["sourcePath"] == "PortableRuntime/source-selection.json"
                            for row in report["sourceManifestReferences"]))
        self.assertTrue(any(row["sourcePath"] == "tools/audit.py"
                            for row in report["directoryReaderSearches"]))

    def test_rejects_untracked_or_missing_candidates(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path = "output/candidate.json"
            (root / "output").mkdir()
            (root / path).write_text("{}\n")
            with self.assertRaisesRegex(ValueError, "Candidates are not tracked"):
                audit(root, [path], [], "a" * 40, "b" * 64)
            (root / path).unlink()
            with self.assertRaisesRegex(ValueError, "Candidate is missing"):
                audit(root, [path], [path], "a" * 40, "b" * 64)

    def test_candidate_self_references_are_not_counted(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path = "evidence/result.json"
            file_path = root / path
            file_path.parent.mkdir()
            file_path.write_text(json.dumps({"path": path}) + "\n")
            report = audit(root, [path], [path], "a" * 40, "b" * 64)
        self.assertEqual(report["candidates"][0]["references"], [])
        self.assertEqual(report["structuredReferences"], [])
        self.assertEqual(report["textReferences"], [])


if __name__ == "__main__":
    unittest.main()
