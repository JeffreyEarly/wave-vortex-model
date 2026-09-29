"""Synthetic tests for benchmark download validation and staging."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import website_downloads as downloads


PUBLISHED_ID = "demo-v1--matlab-builtin--runner--20260101T010203Z"
INTERFACE_ID = "three-interface--m5-max--20260101T010203Z"
PUBLISHED_SOURCE = f"Benchmarks/results/published/{PUBLISHED_ID}.json"
INTERFACE_SOURCE = f"Benchmarks/results/published/{INTERFACE_ID}.json"


class WebsiteDownloadTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="wvm-website-downloads-")
        self.root = Path(self.temporary.name) / "repository"
        self.root.mkdir()
        self.manifest = self.root / "docs/benchmarks/downloads.json"
        self.manifest.parent.mkdir(parents=True)
        self.published_bytes = json.dumps({
            "schemaVersion": "published-benchmark-v1",
            "datasetId": PUBLISHED_ID,
            "benchmark": {"suiteId": "demo-v1"},
            "provenance": {"rawArtifact": PUBLISHED_SOURCE},
        }, sort_keys=True).encode() + b"\n"
        self.interface_bytes = json.dumps({
            "schemaVersion": "published-three-interface-v4",
            "datasetId": INTERFACE_ID,
        }, sort_keys=True).encode() + b"\n"
        self._write_source(PUBLISHED_SOURCE, self.published_bytes)
        self._write_source(INTERFACE_SOURCE, self.interface_bytes)
        catalog = {
            "schemaVersion": "benchmark-catalog-v1",
            "scoringReferences": [{"suiteId": "demo-v1"}],
            "publishedDatasets": [{"datasetId": PUBLISHED_ID, "artifact": PUBLISHED_SOURCE}],
            "interfaceComparisons": [{"datasetId": INTERFACE_ID, "artifact": INTERFACE_SOURCE}],
        }
        self._write_source("Benchmarks/results/catalog.json", json.dumps(catalog).encode() + b"\n")
        self.valid_rows = [
            self._entry(f"/benchmarks/data/{PUBLISHED_ID}.json", PUBLISHED_SOURCE),
            self._entry(f"/benchmarks/data/{INTERFACE_ID}.json", INTERFACE_SOURCE),
            self._entry(f"/benchmarks/raw/{PUBLISHED_ID}.json", PUBLISHED_SOURCE),
        ]
        self.valid_rows.sort(key=lambda row: row["url"])
        self._write_manifest(self.valid_rows)

    def tearDown(self):
        self.temporary.cleanup()

    def _write_source(self, relative, content):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def _entry(self, url, source):
        content = (self.root / source).read_bytes()
        return {"url": url, "source": source,
                "sha256": hashlib.sha256(content).hexdigest(), "bytes": len(content)}

    def _write_manifest(self, rows):
        self.manifest.write_text(json.dumps({"schema": downloads.SCHEMA, "entries": rows}, indent=2) + "\n")

    def test_stages_identical_source_aliases_and_verifies_without_repair(self):
        entries = downloads.validate_manifest(self.root, self.manifest)
        destination = Path(self.temporary.name) / "staging" / "docs"

        downloads.stage_downloads(self.root, entries, destination)
        downloads.stage_downloads(self.root, entries, destination)
        downloads.verify_staged(self.root, entries, destination)

        normalized = destination / "benchmarks/data" / f"{PUBLISHED_ID}.json"
        raw = destination / "benchmarks/raw" / f"{PUBLISHED_ID}.json"
        interface = destination / "benchmarks/data" / f"{INTERFACE_ID}.json"
        self.assertEqual(normalized.read_bytes(), self.published_bytes)
        self.assertEqual(raw.read_bytes(), self.published_bytes)
        self.assertEqual(interface.read_bytes(), self.interface_bytes)
        self.assertEqual(normalized.read_bytes(), raw.read_bytes())

    def test_missing_extra_duplicate_traversal_stale_hash_and_wrong_source_fail(self):
        cases = []
        cases.append(("missing", self.valid_rows[:-1], "Missing generated download URL"))

        extra = list(self.valid_rows) + [self._entry("/benchmarks/data/extra-v1.json", PUBLISHED_SOURCE)]
        extra.sort(key=lambda row: row["url"])
        cases.append(("extra", extra, "Unexpected generated download URL"))

        duplicate = list(self.valid_rows) + [dict(self.valid_rows[0])]
        duplicate.sort(key=lambda row: row["url"])
        cases.append(("duplicate", duplicate, "Duplicate download URL"))

        traversal = [dict(row) for row in self.valid_rows]
        traversal[0]["url"] = "/benchmarks/data/../escape.json"
        cases.append(("URL traversal", traversal, "Invalid benchmark download URL"))

        source_traversal = [dict(row) for row in self.valid_rows]
        source_traversal[0]["source"] = "Benchmarks/results/published/../../outside.json"
        cases.append(("source traversal", source_traversal, "canonical Benchmarks/results JSON path"))

        stale = [dict(row) for row in self.valid_rows]
        stale[0]["sha256"] = "0" * 64
        cases.append(("stale hash", stale, "Stale SHA-256"))

        wrong_source_path = "Benchmarks/results/published/wrong-source.json"
        self._write_source(wrong_source_path, b'{"wrong":true}\n')
        wrong = [dict(row) for row in self.valid_rows]
        data_row = next(row for row in wrong if row["url"] == f"/benchmarks/data/{PUBLISHED_ID}.json")
        data_row.update(self._entry(data_row["url"], wrong_source_path))
        cases.append(("wrong source", wrong, "Wrong source for generated download URL"))

        for label, rows, expected_message in cases:
            with self.subTest(label=label):
                self._write_manifest(rows)
                with self.assertRaisesRegex(downloads.DownloadError, expected_message):
                    downloads.validate_manifest(self.root, self.manifest)

    def test_accepts_manifest_in_temporary_build_tree(self):
        build_manifest = Path(self.temporary.name) / "build" / "benchmarks" / "downloads.json"
        build_manifest.parent.mkdir(parents=True)
        build_manifest.write_text(json.dumps({"schema": downloads.SCHEMA, "entries": self.valid_rows}) + "\n")

        entries = downloads.validate_manifest(self.root, build_manifest.resolve())

        self.assertEqual(len(entries), 3)

    def test_rejects_manifest_symlinks(self):
        build_manifest = Path(self.temporary.name) / "build" / "benchmarks" / "downloads.json"
        build_manifest.parent.mkdir(parents=True)
        build_manifest.write_text(json.dumps({"schema": downloads.SCHEMA, "entries": self.valid_rows}) + "\n")
        alias = Path(self.temporary.name) / "downloads-link.json"
        alias.symlink_to(build_manifest)

        with self.assertRaisesRegex(downloads.DownloadError, "Manifest cannot be a symlink"):
            downloads.validate_manifest(self.root, alias)

    def test_rejects_source_symlink_escape(self):
        outside = Path(self.temporary.name) / "outside.json"
        outside.write_bytes(self.published_bytes)
        source = self.root / PUBLISHED_SOURCE
        source.unlink()
        source.symlink_to(outside)

        with self.assertRaisesRegex(downloads.DownloadError, "contains a symlink"):
            downloads.validate_manifest(self.root, self.manifest)

    def test_refuses_conflicts_destination_symlinks_and_root_docs(self):
        entries = downloads.validate_manifest(self.root, self.manifest)
        conflict_root = Path(self.temporary.name) / "conflict"
        conflict = conflict_root / "benchmarks/data" / f"{PUBLISHED_ID}.json"
        conflict.parent.mkdir(parents=True)
        conflict.write_bytes(b"different bytes")
        with self.assertRaisesRegex(downloads.DownloadError, "Conflicting bytes"):
            downloads.stage_downloads(self.root, entries, conflict_root)

        outside = Path(self.temporary.name) / "outside"
        outside.mkdir()
        symlink_root = Path(self.temporary.name) / "symlink-site"
        symlink_root.mkdir()
        (symlink_root / "benchmarks").symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(downloads.DownloadError, "contains a symlink"):
            downloads.stage_downloads(self.root, entries, symlink_root)

        with self.assertRaisesRegex(downloads.DownloadError, "Destination cannot be ROOT/docs"):
            downloads.stage_downloads(self.root, entries, self.root / "docs")
        self.assertFalse((self.root / "docs/benchmarks/data").exists())

    def test_verify_staged_never_repairs_missing_files(self):
        entries = downloads.validate_manifest(self.root, self.manifest)
        destination = Path(self.temporary.name) / "empty-site"
        destination.mkdir()

        with self.assertRaisesRegex(downloads.DownloadError, "Staged download is missing"):
            downloads.verify_staged(self.root, entries, destination)
        self.assertEqual(list(destination.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
