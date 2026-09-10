import copy
import json
from pathlib import Path
import unittest

from check_compatibility_matrix import MATRIX, check


class CompatibilityAssemblyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parents[2]
        cls.catalog = json.loads((cls.root / MATRIX).read_text())

    def test_committed_inputs_and_fixtures_are_registered(self):
        rows, witnesses = check(self.root, self.catalog)
        self.assertGreater(rows, 666)
        self.assertGreater(witnesses, 0)

    def test_stale_input_cannot_be_published(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['sources'][0]['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'Stale assembly input'):
            check(self.root, catalog)

    def test_deleted_fixture_and_duplicate_row_are_rejected(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['witnesses'][0]['symbol'] = 'missingFixture'
        with self.assertRaisesRegex(ValueError, 'Unresolved witness'):
            check(self.root, catalog)
        catalog = copy.deepcopy(self.catalog)
        catalog['rows'].append(catalog['rows'][0])
        with self.assertRaisesRegex(ValueError, 'Duplicate row'):
            check(self.root, catalog)

    def test_unsupported_claims_cannot_hide_qualification_gaps(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['rows'][0]['status'] = 'supported'
        catalog['rows'][0]['fixtures'] = []
        with self.assertRaisesRegex(ValueError, 'Untested support'):
            check(self.root, catalog)
        catalog['rows'][0]['status'] = 'unqualified'
        catalog['rows'][0].pop('issue', None)
        with self.assertRaisesRegex(ValueError, 'Untracked qualification gap'):
            check(self.root, catalog)

    def test_catalog_cannot_assert_executed_parity(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['readiness']['standardParityReady'] = True
        with self.assertRaisesRegex(ValueError, 'cannot declare executed'):
            check(self.root, catalog)

    def test_forcing_schema_contains_every_current_transform(self):
        schema = json.loads((self.root / 'PortableRuntime/contracts/portable-compatibility-matrix-v1.schema.json').read_text())
        forcing = json.loads((self.root / 'PortableRuntime/contracts/portable-forcing-compatibility-v1.json').read_text())
        allowed = schema['$defs']['configuration']['properties']['transform']['enum']
        self.assertEqual(set(allowed), {row['transform'] for row in forcing['configurations']})
