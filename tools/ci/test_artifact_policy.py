import json
from pathlib import Path
import tempfile
import unittest

from artifact_policy import (
    ArtifactPolicyError,
    build_baseline,
    check_repository,
    parse_baseline,
    render_baseline,
    validate_baseline_transition,
)


class ArtifactPolicyTests(unittest.TestCase):
    BASE_COMMIT = "a" * 40

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.registered = {
            "fixtures/input.json": "fixture",
            "schemas/result.schema.json": "source-schema",
            "contracts/catalog.json": "contract",
            "benchmarks/reference.csv": "benchmark-reference",
            "qualification/current.json": "qualification-evidence",
        }
        for path in self.registered:
            self.write(path, "registered input\n")
        self.write("ci-evidence/old/run.log", "historical log\n")
        self.baseline = build_baseline(self.root, ["ci-evidence/old/run.log"])

    def write(self, relative, content):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def tracked(self):
        return sorted(path.relative_to(self.root).as_posix()
                      for path in self.root.rglob("*") if path.is_file())

    def test_registered_inputs_and_exact_historical_entry_pass(self):
        self.assertEqual(check_repository(self.root, self.tracked(), self.registered, self.baseline), [])

    def test_added_output_is_blocked_even_in_baselined_historical_directory(self):
        self.write("ci-evidence/old/new-retry.log", "new raw output\n")
        errors = check_repository(self.root, self.tracked(), self.registered, self.baseline)
        self.assertEqual(errors, ["Unregistered tracked artifact: ci-evidence/old/new-retry.log"])

    def test_modified_baseline_content_fails(self):
        self.write("ci-evidence/old/run.log", "edited historical log\n")
        errors = check_repository(self.root, self.tracked(), self.registered, self.baseline)
        self.assertEqual(errors, ["Historical artifact content changed: ci-evidence/old/run.log"])

    def test_missing_baseline_entry_requires_matching_retirement(self):
        (self.root / "ci-evidence/old/run.log").unlink()
        errors = check_repository(self.root, self.tracked(), self.registered, self.baseline)
        self.assertEqual(errors, [
            "Baseline entry removed without matching retirement: ci-evidence/old/run.log"
        ])

        retired = {
            "path": "ci-evidence/old/run.log",
            "sha256": self.baseline["entries"][0]["sha256"],
            "reason": "Retired after its evidence link was removed.",
            "sourceCommit": self.BASE_COMMIT,
        }
        new_manifest = {
            "schema": self.baseline["schema"],
            "entries": [],
            "retired": [retired],
        }
        self.assertEqual(check_repository(self.root, self.tracked(), self.registered, new_manifest), [])
        self.assertEqual(validate_baseline_transition(self.baseline, new_manifest, self.BASE_COMMIT), [])

    def test_retired_path_cannot_be_reintroduced(self):
        entry = self.baseline["entries"][0]
        retired = {"path": entry["path"], "sha256": entry["sha256"], "reason": "Removed.", "sourceCommit": self.BASE_COMMIT}
        manifest = {"schema": self.baseline["schema"], "entries": [], "retired": [retired]}
        errors = check_repository(self.root, self.tracked(), self.registered, manifest)
        self.assertEqual(errors, ["Retired artifact path is present again: ci-evidence/old/run.log"])

    def test_base_to_head_transition_requires_immutable_retirement_provenance(self):
        entry = self.baseline["entries"][0]
        base_row = {
            "path": entry["path"],
            "sha256": entry["sha256"],
            "reason": "Removed after reference review.",
            "sourceCommit": self.BASE_COMMIT,
        }
        retired_head = {"schema": self.baseline["schema"], "entries": [], "retired": [base_row]}
        self.assertEqual(validate_baseline_transition(self.baseline, retired_head, self.BASE_COMMIT), [])

        quietly_dropped = {"schema": self.baseline["schema"], "entries": [], "retired": []}
        self.assertEqual(validate_baseline_transition(self.baseline, quietly_dropped, self.BASE_COMMIT), [
            "Baseline entry removed without retirement record: ci-evidence/old/run.log"
        ])
        wrong_hash = {"schema": self.baseline["schema"], "entries": [], "retired": [
            {**base_row, "sha256": "b" * 64}
        ]}
        self.assertEqual(validate_baseline_transition(self.baseline, wrong_hash, self.BASE_COMMIT), [
            "Retirement digest does not match prior baseline: ci-evidence/old/run.log"
        ])
        wrong_source = {"schema": self.baseline["schema"], "entries": [], "retired": [
            {**base_row, "sourceCommit": "c" * 40}
        ]}
        self.assertEqual(validate_baseline_transition(self.baseline, wrong_source, self.BASE_COMMIT), [
            "Retirement source commit does not match base revision: ci-evidence/old/run.log"
        ])

    def test_existing_retirement_rows_are_append_only(self):
        entry = self.baseline["entries"][0]
        retired = {
            "path": entry["path"],
            "sha256": entry["sha256"],
            "reason": "Already reviewed.",
            "sourceCommit": self.BASE_COMMIT,
        }
        previous = {"schema": self.baseline["schema"], "entries": [], "retired": [retired]}
        mutated = {"schema": self.baseline["schema"], "entries": [], "retired": [{**retired, "reason": "Rewritten."}]}
        self.assertEqual(validate_baseline_transition(previous, mutated, "d" * 40), [
            "Retirement record changed or removed: ci-evidence/old/run.log"
        ])

    def test_baseline_builder_is_deterministic_and_requires_explicit_paths(self):
        first = build_baseline(self.root, ["ci-evidence/old/run.log"])
        second = build_baseline(self.root, reversed(["ci-evidence/old/run.log"]))
        self.assertEqual(render_baseline(first), render_baseline(second))
        self.assertEqual(json.loads(render_baseline(first)), first)
        self.assertEqual(check_repository(self.root, self.tracked(), self.registered, first), [])

    def test_baseline_rejects_wildcard_paths_and_duplicate_rows(self):
        with self.assertRaises(ArtifactPolicyError):
            build_baseline(self.root, ["ci-evidence/**"])
        entry = self.baseline["entries"][0]
        duplicate = {"schema": self.baseline["schema"], "entries": [entry, entry], "retired": []}
        with self.assertRaisesRegex(ArtifactPolicyError, "Duplicate baseline path"):
            parse_baseline(duplicate)

    def test_registered_role_must_be_known(self):
        with self.assertRaisesRegex(ArtifactPolicyError, "Unknown registered role"):
            check_repository(self.root, self.tracked(), {"fixtures/input.json": "anything"}, self.baseline)


if __name__ == "__main__":
    unittest.main()
