"""Community listing policy is stricter than the general native validator."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MarketplaceIdentity(unittest.TestCase):
    def test_machine_id_satisfies_the_community_lowercase_contract(self):
        """Catch the uppercase ID that native validation accepted before listing."""
        manifest = json.loads((ROOT / 'manifest.json').read_text())
        identity = manifest['id']
        self.assertEqual(identity, 'omaconnect.plus')
        self.assertEqual(identity, identity.lower())
        self.assertIsNotNone(re.fullmatch(r'[a-z0-9][a-z0-9._-]*', identity))
        self.assertNotIn('..', identity)
        self.assertFalse(identity.startswith('omarchy.'))
        self.assertNotEqual(identity, 'omaconnect')
        self.assertEqual(manifest['name'], 'Omaconnect KDE Plus')
