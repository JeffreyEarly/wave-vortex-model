import unittest
from route import select, FAMILIES


class RoutingTests(unittest.TestCase):
    def test_documentation_does_not_build_numerics(self):
        plan = select(['Documentation/WebsiteDocumentation/users-guide/output.md'])
        self.assertTrue(plan['documentation'])
        self.assertFalse(plan['cpp'])
        self.assertFalse(plan['packaging'])
        self.assertEqual(plan['releases'], ['R2025b'])

    def test_boussinesq_source_selects_its_consumers(self):
        plan = select(['CompiledKernel/src/WVTransformBoussinesqKernel.cpp'])
        self.assertEqual(plan['families'], ['boussinesq'])
        self.assertTrue(plan['cpp'])
        self.assertTrue(plan['diagnostics'])
        self.assertIn('TestPortableBoussinesqQualification', plan['matlabTests'])
        self.assertNotIn('TestPortableHydrostatic', plan['matlabTests'])

    def test_shared_persistence_covers_all_families(self):
        plan = select(['PortableRuntime/src/WVCheckpointWriter.cpp'])
        self.assertEqual(set(plan['families']), set(FAMILIES))
        self.assertIn('TestPortableRuntimeCompatibility', plan['matlabTests'])
        self.assertIn('TestWVModelOutputPersistence', plan['matlabTests'])
        self.assertTrue(plan['crossRelease'])

    def test_matlab_source_preserves_compatibility_and_documentation(self):
        plan = select(['@WVTransformHydrostatic/WVTransformHydrostatic.m'])
        self.assertTrue(plan['analyzer'])
        self.assertTrue(plan['documentation'])
        self.assertEqual(plan['releases'], ['R2025b', 'R2026a'])
        self.assertEqual(plan['families'], ['hydrostatic'])

    def test_ci_and_unknown_paths_are_conservative(self):
        for path in ['.github/workflows/ci.yml', 'tools/ci/route.py', 'new-scientific-module/example.cpp', 'new-module.m']:
            with self.subTest(path=path):
                plan = select([path])
                self.assertEqual(set(plan['families']), set(FAMILIES))
                self.assertTrue(plan['packaging'])
                self.assertTrue(plan['documentation'])
                self.assertTrue(plan['analyzer'])

    def test_evidence_does_not_restart_numerical_qualification(self):
        plan = select(['.github/ci-evidence/issue-395-after.json'])
        self.assertFalse(plan['cpp'])
        self.assertFalse(plan['documentation'])

    def test_changes_union_without_repeating_common_tests(self):
        paths = ['CompiledKernel/src/WVTransformHydrostaticKernel.cpp', 'CompiledKernel/src/WVTransformBoussinesqKernel.cpp']
        plan = select(paths + paths)
        self.assertEqual(plan, select(list(reversed(paths))))
        self.assertEqual(plan['matlabTests'].count('TestPortableStableForcing'), 1)

    def test_deleted_and_renamed_paths_receive_normal_routing(self):
        # git --no-renames supplies both sides; no existence test may discard a deletion.
        plan = select(['@WVTransformHydrostatic/deleted.m', '@WVTransformBoussinesq/new.m'])
        self.assertEqual(plan['families'], ['boussinesq', 'hydrostatic'])

    def test_complete_and_empty_inventory_fail_conservatively(self):
        for plan in [select([]), select(['README.md'], complete=True)]:
            self.assertEqual(set(plan['families']), set(FAMILIES))
            self.assertTrue(plan['packaging'])
        self.assertFalse(select(['README.md'])['complete'])
        self.assertEqual(select(['README.md'], complete=True)['deferredMethods'], [])

    def test_legacy_migration_executes_required_phases(self):
        plan = select(['README.md'], migration=True)
        self.assertTrue(plan['documentation'])
        self.assertTrue(plan['analyzer'])

    def test_invalid_paths_are_rejected(self):
        for path in ['/tmp/code.cpp', '../code.cpp', 'a/../../code.cpp', 'a\nb.cpp']:
            with self.assertRaises(ValueError):
                select([path])

    def test_batches_preserve_each_selected_class_exactly_once(self):
        for paths in [['README.md'], ['CompiledKernel/src/WVTransformBoussinesqKernel.cpp'], ['.github/workflows/ci.yml']]:
            plan = select(paths)
            for classes, groups in [('matlabTests', 'matlabShards'), ('sanitizedTests', 'sanitizedShards')]:
                flattened = [name for group in plan[groups] for name in group['classes']]
                self.assertEqual(sorted(flattened), plan[classes])
                self.assertEqual(len(flattened), len(set(flattened)))
                self.assertLessEqual(len(plan[groups]), 4)
                self.assertEqual([group['id'] for group in plan[groups]], list(range(len(plan[groups]))))
        self.assertEqual(len(select(['README.md'])['matlabShards']), 1)
        self.assertGreater(len(select(['CompiledKernel/src/WVTransformBoussinesqKernel.cpp'])['matlabShards']), 1)


if __name__ == '__main__':
    unittest.main()
