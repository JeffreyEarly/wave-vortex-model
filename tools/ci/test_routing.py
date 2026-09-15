"""Fast stdlib tests for path routing, real git diffs, and the required gate."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from classify_changes import (
    BOUSSINESQ, COMPILED, CORE, DEFERRED_TESTS, DOC_TESTS, FORCING, FORCING_REGRESSIONS,
    INTEGRATION, OPERATIONS, PARTIAL_TESTS, PERSISTENCE, QG, ROUTINE_TESTS,
    THERMAL, classify_changes, parse_name_status, read_change,
)
from check_required_gate import check_gate


class RoutingTests(unittest.TestCase):
    def assert_lightweight(self, paths, **kwargs):
        plan = classify_changes(paths, **kwargs)
        self.assertFalse(any(plan[key] for key in ("matlab", "cpp", "documentation", "package")), plan)
        self.assertEqual(plan["tests"], [])
        self.assertEqual(plan["errors"], [])

    def test_artifact_policy_and_study_changes_are_lightweight(self):
        self.assert_lightweight([
            "AGENTS.md", ".gitignore", "README.md", "tools/checkRepositoryArtifacts.py",
            "tools/test_checkRepositoryArtifacts.py", "tools/ci/classify_changes.py",
            "tools/aliasing-study/README.md", "tools/aliasing-study/runStudy.m",
            "tools/aliasing-study/results/summary.csv", "Documentation/Validation/evidence.md",
        ], deleted=["tools/aliasing-study/results/summary.csv"])

    def test_deleted_study_scripts_remain_housekeeping(self):
        paths = ["tools/old-study/runStudy.m", "tools/old-study/results/provenance.json"]
        self.assert_lightweight(paths, deleted=paths)

    def test_retired_dataset_test_is_housekeeping_only_when_deleted(self):
        path = "UnitTests/TestBenchmarkWebsiteDocumentation.m"
        self.assert_lightweight([path], deleted=[path])
        self.assertTrue(classify_changes([path])["errors"])

    def test_workflow_routing_edits_do_not_provision_runtimes(self):
        self.assert_lightweight([
            ".github/workflows/ci.yml", ".github/workflows/extended-ci.yml",
            ".github/workflows/release-verification.yml",
        ])

    def test_production_domains_have_scientific_coverage_beyond_smoke(self):
        for path, expected in {
            "@WVTransform/reconstructFields.m": CORE,
            "@WVTransformFreeSurfaceBoussinesq/coefficientTendency.m": BOUSSINESQ,
            "@WVTransformFreeSurfaceQG/diffZ.m": QG,
            "@WVTransformFreeSurfaceThermalQG/coefficientTendency.m": THERMAL,
            "Forcing/WVAdaptiveDamping.m": FORCING + FORCING_REGRESSIONS["WVAdaptiveDamping"],
            "@WVModel/integrateToTime.m": INTEGRATION + PERSISTENCE,
            "Integrators/WVModelAdaptiveTimeStepMethods.m": INTEGRATION + PERSISTENCE,
            "Operations/WVFluidVariableOperation.m": OPERATIONS + CORE,
            "FastTransforms/transform.m": CORE,
            "@WVCompiledBackend/build.m": COMPILED,
        }.items():
            with self.subTest(path=path):
                plan = classify_changes([path])
                self.assertTrue(plan["matlab"])
                self.assertEqual(set(plan["tests"]), set(expected))
                self.assertEqual(plan["analyzer_files"], [path])
                self.assertFalse(plan["documentation"])

    def test_deleted_production_keeps_regressions_but_has_no_analyzer_file(self):
        path = "@WVTransform/reconstructFields.m"
        plan = classify_changes([path], deleted=[path])
        self.assertTrue(plan["matlab"])
        self.assertEqual(plan["tests"], list(CORE))
        self.assertEqual(plan["analyzer_files"], [])

    def test_api_help_or_signature_change_adds_documentation(self):
        path = "@WVTransform/reconstructFields.m"
        self.assertTrue(classify_changes([path], api_changed=[path])["documentation"])

    def test_direct_regression_change_runs_the_regression(self):
        plan = classify_changes(["UnitTests/TestThermalDiagnostics.m"])
        self.assertEqual(plan["tests"], ["TestThermalDiagnostics"])
        self.assertTrue(plan["matlab"])

    def test_benchmark_fixture_change_excludes_native_workers(self):
        plan = classify_changes(["UnitTests/TestCompiledPreviewBenchmark.m"])
        self.assertEqual(plan["tests"], ["TestCompiledPreviewBenchmark/publicNormalizationCarriesExactAndRSSMemory"])

    def test_unmapped_test_requires_explicit_reviewed_routing(self):
        plan = classify_changes(["UnitTests/TestNewScientificMethod.m"])
        self.assertTrue(plan["matlab"])
        self.assertEqual(len(plan["errors"]), 1)
        self.assertIn("add a reviewed", plan["errors"][0])

    def test_removed_test_uses_conservative_surviving_regressions(self):
        path = "UnitTests/TestRemoved.m"
        plan = classify_changes([path], deleted=[path])
        self.assertEqual(set(plan["tests"]), set(CORE + INTEGRATION))
        self.assertEqual(plan["errors"], [])
        self.assertEqual(plan["analyzer_files"], [])

    def test_long_study_does_not_get_scheduled_in_pr(self):
        for name in DEFERRED_TESTS:
            with self.subTest(name=name):
                plan = classify_changes([f"UnitTests/{name}.m"])
                self.assertTrue(plan["matlab"])
                self.assertNotIn(name, plan["tests"])
                self.assertTrue(plan["tests"])
                self.assertEqual(plan["errors"], [])

    def test_cpp_source_and_build_configuration_route_contracts_and_sanitizers(self):
        for path in ["CompiledKernel/src/core.cpp", "PortableRuntime/CMakeLists.txt",
                     "PortableRuntime/include/runtime.hpp", "PortableRuntime/source-selection.json",
                     "tools/compiled-kernel/run_contract_tests.sh", "new-native/component.cpp"]:
            with self.subTest(path=path):
                plan = classify_changes([path])
                self.assertTrue(plan["cpp"])
                self.assertFalse(plan["matlab"])
        self.assert_lightweight(["PortableRuntime/README.md"])

    def test_package_contract_changes_select_install_export_and_tests(self):
        for path in ["resources/mpackage.json", "tools/configureCIEnvironment.m",
                     "tools/verifyWaveVortexModelPackage.m", ".github/workflows/release-mpm.yml"]:
            with self.subTest(path=path):
                plan = classify_changes([path])
                self.assertTrue(plan["package"])
                self.assertTrue(plan["matlab"])
                self.assertEqual(set(plan["tests"]), set(CORE + INTEGRATION))
        self.assertTrue(classify_changes([".github/workflows/ci.yml"], dependency_changed=True)["package"])

    def test_actual_documentation_changes_run_docs_check(self):
        for path in ["Documentation/WebsiteDocumentation/users-guide/example.md", "docs/index.md",
                     "@WVTransform/variableWithName.md", "tools/check_website_documentation.m", "CHANGELOG.md"]:
            with self.subTest(path=path):
                plan = classify_changes([path])
                self.assertTrue(plan["documentation"])
                self.assertFalse(plan["matlab"])
                self.assertFalse(plan["cpp"])

    def test_unknown_production_paths_fail_conservative_without_long_studies(self):
        for path in ["newRuntimeFunction.m", "+NewPackage/helper.m", "NewProduction/input.dat"]:
            with self.subTest(path=path):
                plan = classify_changes([path])
                self.assertTrue(plan["matlab"])
                self.assertEqual(set(plan["tests"]), set(CORE + INTEGRATION))

    def test_rename_tracks_old_and_new_paths(self):
        paths, deleted = parse_name_status(b"R100\0@WVTransform/a.m\0tools/old-study/a.m\0D\0tools/old-study/results/a.csv\0")
        self.assertEqual(paths, {"@WVTransform/a.m", "tools/old-study/a.m", "tools/old-study/results/a.csv"})
        self.assertEqual(deleted, {"@WVTransform/a.m", "tools/old-study/results/a.csv"})
        self.assertTrue(classify_changes(paths, deleted=deleted)["matlab"])

    def test_rename_from_policy_to_source_and_paths_with_whitespace(self):
        paths, deleted = parse_name_status(b"R090\0tools/study/old name.m\0Forcing/new name.m\0A\0tools/study/a\nb.csv\0")
        self.assertIn("tools/study/a\nb.csv", paths)
        plan = classify_changes(paths, deleted=deleted)
        self.assertEqual(set(plan["tests"]), set(FORCING))
        self.assertEqual(plan["analyzer_files"], ["Forcing/new name.m"])

    def test_mapping_targets_exist_in_current_repository(self):
        root = Path(__file__).resolve().parents[2]
        selectors = set(CORE + INTEGRATION + FORCING + OPERATIONS + QG + BOUSSINESQ
                        + THERMAL + PERSISTENCE + COMPILED + DOC_TESTS)
        selectors.update(ROUTINE_TESTS | DEFERRED_TESTS)
        for selected in PARTIAL_TESTS.values():
            selectors.update(selected)
        for selected in FORCING_REGRESSIONS.values():
            selectors.update(selected)
        for selector in selectors:
            name, _, method = selector.partition("/")
            with self.subTest(selector=selector):
                source = (root / "UnitTests" / f"{name}.m").read_text()
                self.assertRegex(source, rf"classdef\s+{name}\s+<\s+matlab\.unittest\.TestCase")
                if method:
                    self.assertRegex(source, rf"function\s+{method}\(")


class GitDiffTests(unittest.TestCase):
    def test_real_diff_preserves_rename_and_distinguishes_help_from_implementation(self):
        original = Path.cwd()
        with tempfile.TemporaryDirectory() as folder:
            try:
                os.chdir(folder)
                executable = os.environ.get("GIT", "git")
                def git(*args):
                    return subprocess.check_output([executable, *args], stderr=subprocess.DEVNULL).decode().strip()
                git("init")
                git("config", "user.name", "CI routing test")
                git("config", "user.email", "ci@example.invalid")
                Path("@WVTransform").mkdir()
                Path("tools/example-study").mkdir(parents=True)
                source = Path("@WVTransform/value.m")
                source.write_text("function value = value()\n% Original help.\nvalue = 1;\nend\n")
                Path("tools/example-study/old.csv").write_text("a,b\n1,2\n")
                git("add", ".")
                git("commit", "-m", "base")
                base = git("rev-parse", "HEAD")
                source.write_text(source.read_text().replace("value = 1", "value = 2"))
                Path("tools/example-study/old.csv").rename("tools/example-study/new.csv")
                git("add", ".")
                git("commit", "-m", "implementation and rename")
                plan = read_change(base, "HEAD")
                self.assertTrue(plan["matlab"])
                self.assertFalse(plan["documentation"])
                self.assertTrue(any("old.csv" in reason for reason in plan["reasons"]))
                source.write_text(source.read_text().replace("Original help", "Changed help"))
                git("add", ".")
                git("commit", "-m", "help")
                self.assertTrue(read_change(base, "HEAD")["documentation"])
            finally:
                os.chdir(original)


class RequiredGateTests(unittest.TestCase):
    def needs(self, enabled=()):
        outputs = {route: str(route in enabled).lower() for route in ("cpp", "matlab", "documentation", "package")}
        needs = {"changes": {"result": "success", "outputs": outputs}}
        for job, route in {"kernel-contract": "cpp", "portable-runtime-sanitizers": "cpp", "focused-matlab": "matlab", "documentation": "documentation", "package": "package"}.items():
            needs[job] = {"result": "success" if route in enabled else "skipped"}
        return needs

    def test_lightweight_and_selected_gates_pass(self):
        check_gate(self.needs())
        check_gate(self.needs(("cpp", "matlab", "documentation", "package")))

    def test_selected_failure_cancel_or_skip_blocks(self):
        for result in ("failure", "cancelled", "skipped"):
            needs = self.needs(("matlab",))
            needs["focused-matlab"]["result"] = result
            with self.assertRaises(ValueError):
                check_gate(needs)

    def test_failed_classification_or_missing_output_blocks(self):
        needs = self.needs()
        needs["changes"]["result"] = "failure"
        with self.assertRaises(ValueError):
            check_gate(needs)
        needs = self.needs()
        del needs["changes"]["outputs"]["cpp"]
        with self.assertRaises(ValueError):
            check_gate(needs)


class WorkflowPolicyTests(unittest.TestCase):
    def test_long_suites_have_no_pull_request_or_push_trigger(self):
        root = Path(__file__).resolve().parents[2]
        workflow = (root / ".github/workflows/extended-ci.yml").read_text()
        triggers = workflow.split("permissions:", 1)[0]
        self.assertNotIn("pull_request:", triggers)
        self.assertNotIn("push:", triggers)
        for event in ("schedule:", "workflow_dispatch:", "release:"):
            self.assertIn(event, triggers)

    def test_required_gate_is_always_present_and_requires_classification(self):
        root = Path(__file__).resolve().parents[2]
        workflow = (root / ".github/workflows/ci.yml").read_text()
        self.assertIn("name: Required / WaveVortexModel", workflow)
        self.assertIn("  required-gate:\n    if: always()", workflow)
        self.assertIn("needs: [changes, kernel-contract, portable-runtime-sanitizers, focused-matlab, documentation, package]", workflow)
        self.assertNotIn("final-integration", workflow)
        for task in ("test:full", "test:exhaustive", "test:optional"):
            self.assertNotIn(task, workflow)
        self.assertIn('assert(~isempty(suite)', workflow)
        self.assertIn('assertSuccess(results)', workflow)


if __name__ == "__main__":
    unittest.main()
