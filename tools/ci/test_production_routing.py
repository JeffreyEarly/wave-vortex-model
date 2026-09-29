"""Regression fixtures for production dependency and analyzer routing."""
import copy
import unittest

from diff_content import documentation_changed, matlab_documentation_signature
from route import FAMILIES, select


class ProductionDependencyRoutingTests(unittest.TestCase):
    def test_family_native_and_matlab_sources_select_their_family(self):
        native_path = 'CompiledKernel/src/WVTransformHydrostaticKernel.cpp'
        matlab_path = '@WVTransformHydrostatic/WVTransformHydrostatic.m'

        native = select([native_path])
        matlab = select([matlab_path], surviving_matlab=[matlab_path])

        self.assertEqual(native['families'], ['hydrostatic'])
        self.assertTrue(native['cpp'])
        self.assertTrue(native['sanitized'])
        self.assertIn('TestHydrostaticCompiledKernel', native['matlabTests'])
        self.assertEqual(matlab['families'], ['hydrostatic'])
        self.assertIn('TestPortableHydrostatic', matlab['matlabTests'])
        self.assertTrue(matlab['matlabCore'])
        self.assertEqual(matlab['analyzerMode'], 'changed')
        self.assertEqual(matlab['analyzerFiles'], [matlab_path])

    def test_native_family_routes_keep_native_contract_execution_enabled(self):
        for path in [
            'CompiledKernel/src/WVTransformConstantStratificationKernel.cpp',
            'PortableRuntime/src/WVHydrostaticIntegrationSystem.cpp',
        ]:
            with self.subTest(path=path):
                plan = select([path])
                self.assertTrue(plan['cpp'])
                self.assertTrue(plan['sanitized'])
                self.assertTrue(plan['families'])

    def test_shared_forcing_integration_and_persistence_fan_out(self):
        cases = [
            ('Forcing/WVForcingType.m', 'forcing'),
            ('Integrators/WVArrayIntegrator.m', 'integration'),
            ('WVModelOutputGroup.m', 'persistence'),
        ]
        for path, rule in cases:
            with self.subTest(path=path):
                plan = select([path], surviving_matlab=[path])
                self.assertEqual(set(plan['families']), set(FAMILIES))
                self.assertIn(rule, plan['productionRules'])
                self.assertTrue(plan['persistence'])
                self.assertTrue(plan['matlabCore'])
                self.assertTrue(plan['cpp'])
                self.assertTrue(plan['analyzer'])

    def test_unknown_keyword_looking_source_uses_broad_fallback(self):
        plan = select(['experimental/hydrostatic-engine.cpp'])

        self.assertEqual(set(plan['families']), set(FAMILIES))
        self.assertTrue(plan['packaging'])
        self.assertTrue(plan['documentation'])
        self.assertTrue(plan['analyzer'])
        self.assertEqual(plan['analyzerMode'], 'production')

    def test_api_sidecar_documentation_selects_documentation_without_science(self):
        plan = select(['@WVTransformHydrostatic/README.md'])

        self.assertTrue(plan['matlab'])
        self.assertTrue(plan['documentation'])
        self.assertFalse(plan['smoke'])
        self.assertFalse(plan['cpp'])
        self.assertEqual(plan['families'], [])
        self.assertEqual(plan['matlabTests'], [])

    def test_body_only_facts_omit_docs_while_api_facts_select_them(self):
        path = '@WVTransformHydrostatic/WVTransformHydrostatic.m'
        body_only = select([path], implementation_only_matlab=[path], surviving_matlab=[path])
        api_changed = select([path], surviving_matlab=[path])

        self.assertFalse(body_only['documentation'])
        self.assertEqual(body_only['analyzerMode'], 'changed')
        self.assertEqual(body_only['analyzerFiles'], [path])
        self.assertTrue(api_changed['documentation'])
        self.assertEqual(api_changed['analyzerMode'], 'changed')
        self.assertEqual(api_changed['analyzerFiles'], [path])

    def test_analyzer_files_include_changed_survivors_but_exclude_deleted_sources(self):
        survivor = '@WVTransformHydrostatic/Existing.m'
        deleted = '@WVTransformHydrostatic/Deleted.m'
        plan = select(
            [deleted, survivor],
            implementation_only_matlab=[survivor],
            surviving_matlab=[survivor],
        )

        self.assertEqual(plan['analyzerMode'], 'changed')
        self.assertEqual(plan['analyzerFiles'], [survivor])
        self.assertTrue(plan['documentation'])

    def test_analyzer_policy_package_and_complete_routes_use_full_analysis(self):
        for paths, complete in [
            (['tools/analyzeProductionCode.m'], False),
            (['tools/verifyWaveVortexModelPackage.m'], False),
            (['README.md'], True),
        ]:
            with self.subTest(paths=paths, complete=complete):
                plan = select(paths, complete=complete)
                self.assertTrue(plan['analyzer'])
                self.assertEqual(plan['analyzerMode'], 'production')
                self.assertEqual(plan['analyzerFiles'], [])
                if 'verifyWaveVortexModelPackage.m' in paths or complete:
                    self.assertTrue(plan['packaging'])

    def test_direct_test_selection_survives_family_consumer_filtering(self):
        direct = 'UnitTests/TestPortableDensityOutput.m'
        family_source = 'CompiledKernel/src/WVTransformStratifiedQGKernel.cpp'
        plan = select([direct, family_source])

        self.assertEqual(plan['families'], ['sqg'])
        self.assertIn('TestPortableDensityOutput', plan['matlabTests'])
        self.assertIn('TestPortableDensityOutput', plan['sanitizedTests'])


class ProductionAnalyzerGateTests(unittest.TestCase):
    def test_gate_accepts_exact_changed_file_analysis_and_rejects_incomplete_evidence(self):
        from gate import validate
        from test_gate import evidence

        path = '@WVTransformHydrostatic/WVTransformHydrostatic.m'
        plan = select([path], source_commit='fixture-revision', surviving_matlab=[path])
        jobs, reports = evidence(plan)

        self.assertTrue(validate(plan, jobs, reports))

        incomplete = copy.deepcopy(reports)
        analyzer_report = next(report for report in incomplete if report['phases']['analyzer'])
        analyzer_report['analyzedFiles'] = []
        with self.assertRaises(ValueError):
            validate(plan, jobs, incomplete)

    def test_gate_requires_production_analysis_evidence_for_policy_changes(self):
        from gate import validate
        from test_gate import evidence

        plan = select(['tools/analyzeProductionCode.m'], source_commit='fixture-revision')
        jobs, reports = evidence(plan)
        self.assertTrue(validate(plan, jobs, reports))

        changed_mode = copy.deepcopy(reports)
        analyzer_report = next(report for report in changed_mode if report['phases']['analyzer'])
        analyzer_report['analyzerMode'] = 'changed'
        with self.assertRaises(ValueError):
            validate(plan, jobs, changed_mode)


class DocumentationParserSafetyTests(unittest.TestCase):
    def test_script_block_comment_with_fake_declaration_stays_unknown(self):
        script = """%{
function fake = apparentAPI(input)
This is a comment, not an executable declaration.
%}
value = 1;
"""

        self.assertIsNone(matlab_documentation_signature(script))
        self.assertTrue(documentation_changed(script, script.replace('value = 1', 'value = 2')))

    def test_missing_closing_parenthesis_in_continued_declaration_is_uncertain(self):
        malformed = """function value = compute(input, ...
value = input + 1;
end
"""
        changed_body = malformed.replace('input + 1', 'input * 2')

        self.assertIsNone(matlab_documentation_signature(malformed))
        self.assertTrue(documentation_changed(malformed, changed_body))


if __name__ == '__main__':
    unittest.main()
