"""Fixtures for conservative MATLAB documentation-impact classification."""
import os
import subprocess
import tempfile
from pathlib import Path
import unittest

from diff_content import documentation_changed, matlab_diff_facts, matlab_documentation_signature


FUNCTION_BEFORE = """function value = example(input)
% EXAMPLE Return a transformed value.
value = input + 1;
end
"""


class MatlabDocumentationSignatureTests(unittest.TestCase):
    def test_body_only_change_preserves_documentation_signature(self):
        after = FUNCTION_BEFORE.replace('input + 1', 'input * 2')

        self.assertFalse(documentation_changed(FUNCTION_BEFORE, after))

    def test_help_and_declaration_changes_select_documentation(self):
        changed_signature = FUNCTION_BEFORE.replace('example(input)', 'example(input, options)')
        changed_help = FUNCTION_BEFORE.replace('Return a transformed value.', 'Return a normalized value.')

        self.assertTrue(documentation_changed(FUNCTION_BEFORE, changed_signature))
        self.assertTrue(documentation_changed(FUNCTION_BEFORE, changed_help))

    def test_public_property_and_argument_blocks_select_documentation(self):
        before = """classdef Example
    properties
        Value (1,1) double = 1
    end
    methods
        function result = run(object, input)
            arguments
                object
                input (1,1) double
            end
            result = input;
        end
    end
end
"""
        changed_property = before.replace('Value (1,1) double = 1', 'Value (1,1) single = 1')
        changed_argument = before.replace('input (1,1) double', 'input (1,1) double {mustBePositive}')

        self.assertTrue(documentation_changed(before, changed_property))
        self.assertTrue(documentation_changed(before, changed_argument))

    def test_class_metadata_change_selects_documentation(self):
        before = """classdef (Sealed) Example
    methods
        function result = run(object)
            result = 1;
        end
    end
end
"""
        after = before.replace('classdef (Sealed)', 'classdef')

        self.assertTrue(documentation_changed(before, after))

    def test_method_access_and_validation_metadata_select_documentation(self):
        before = """classdef Example
    properties (SetAccess=private)
        Value (1,1) double {mustBePositive} = 1
    end
    methods (Access=protected)
        function result = run(object)
            result = object.Value;
        end
    end
end
"""
        changed = before.replace('Access=protected', 'Access=public')

        self.assertTrue(documentation_changed(before, changed))

    def test_scripts_dynamic_annotations_and_uncertain_declarations_are_conservative(self):
        script = """% Script help
value = 1;
"""
        dynamic = FUNCTION_BEFORE + '% annotation = makeWVAnnotation();\n'
        malformed = """function value = example(input, ...
value = input;
"""

        self.assertIsNone(matlab_documentation_signature(script))
        self.assertTrue(documentation_changed(FUNCTION_BEFORE, script))
        self.assertTrue(documentation_changed(FUNCTION_BEFORE, dynamic))
        self.assertTrue(documentation_changed(FUNCTION_BEFORE, malformed))
        self.assertTrue(documentation_changed(None, FUNCTION_BEFORE))


class MatlabDiffFactTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='wvm-ci-diff-facts-')
        self.root = Path(self.temporary.name)
        self.original_cwd = Path.cwd()
        self.git('init', '-q')
        self.git('config', 'user.name', 'CI Fixture')
        self.git('config', 'user.email', 'ci-fixture@example.invalid')
        os.chdir(self.root)

    def tearDown(self):
        os.chdir(self.original_cwd)
        self.temporary.cleanup()

    def git(self, *arguments):
        return subprocess.check_output(['git', '-C', str(self.root), *arguments], text=True).strip()

    def write(self, relative_path, content):
        path = self.root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def commit(self, message):
        self.git('add', '-A')
        self.git('commit', '-q', '-m', message)
        return self.git('rev-parse', 'HEAD')

    def test_deleted_and_renamed_files_remain_documentation_changes(self):
        self.write('Kept.m', FUNCTION_BEFORE)
        self.write('OldName.m', FUNCTION_BEFORE)
        base = self.commit('base')

        self.write('Kept.m', FUNCTION_BEFORE.replace('input + 1', 'input * 2'))
        self.git('mv', 'OldName.m', 'NewName.m')
        head = self.commit('implementation change and rename')

        surviving, implementation_only = matlab_diff_facts(
            base, head, ['Kept.m', 'OldName.m', 'NewName.m'])

        self.assertEqual(surviving, ['Kept.m', 'NewName.m'])
        self.assertEqual(implementation_only, ['Kept.m'])

    def test_deleted_file_is_not_an_analyzer_path_and_is_not_implementation_only(self):
        self.write('Deleted.m', FUNCTION_BEFORE)
        base = self.commit('base')
        self.git('rm', '-q', 'Deleted.m')
        head = self.commit('delete source')

        surviving, implementation_only = matlab_diff_facts(base, head, ['Deleted.m'])

        self.assertEqual(surviving, [])
        self.assertEqual(implementation_only, [])

    def test_unknown_script_and_malformed_file_changes_are_not_documentation_skips(self):
        self.write('Unknown.m', FUNCTION_BEFORE)
        self.write('Script.m', '% A script\nvalue = 1;\n')
        self.write('Malformed.m', 'function value = broken(input, ...\nvalue = input;\n')
        base = self.commit('base')

        self.write('Unknown.m', FUNCTION_BEFORE.replace('input + 1', 'input - 1'))
        self.write('Script.m', '% A script\nvalue = 2;\n')
        self.write('Malformed.m', 'function value = broken(input, ...\nvalue = input + 1;\n')
        head = self.commit('edit uncertain sources')

        surviving, implementation_only = matlab_diff_facts(
            base, head, ['Unknown.m', 'Script.m', 'Malformed.m'])

        self.assertEqual(surviving, ['Malformed.m', 'Script.m', 'Unknown.m'])
        self.assertEqual(implementation_only, ['Unknown.m'])


if __name__ == '__main__':
    unittest.main()
