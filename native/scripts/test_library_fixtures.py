"""Canonical Library fixtures and adaptive/default typography profile regression."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class LibraryFixtures(unittest.TestCase):
    def test_canonical_artwork_is_explicit(self):
        fixtures = json.loads((ROOT / 'uitests/Fixtures.json').read_text())
        expected = ['neon.fixture.quiet-sea', 'neon.fixture.stone-paths', 'neon.fixture.glass-field']
        for name, variant in fixtures['variants'].items():
            projects = variant['projects']
            self.assertEqual([p['fixtureID'] for p in projects[:3]], expected[:len(projects[:3])])
            self.assertTrue(all(p['artwork'] is None for p in projects[3:]))
            if name == 'longtext':
                self.assertIn('a long project title', projects[0]['title'])
            elif projects:
                self.assertEqual(projects[0]['title'], 'The Quiet Sea')
        self.assertEqual([p['title'] for p in fixtures['variants']['3']['projects']],
                         ['The Quiet Sea', 'Stone Paths', 'The Glass Field'])

    def test_default_profiles_allow_adaptive_measure_and_spacing(self):
        profiles = json.loads((ROOT / 'uitests/Fixtures.json').read_text())['preference_profiles']
        for name, profile in profiles.items():
            self.assertIsInstance(profile['manuscriptFont'], str)
            self.assertGreater(profile['manuscriptSize'], 0)
            self.assertIn(profile['appearance'], [0, 1, 2])
            for key in ['manuscriptSpacing', 'textMeasure']:
                if key in profile:
                    self.assertIsInstance(profile[key], (int, float))
                    self.assertGreaterEqual(profile[key], 0)
            if name in ['desktop', 'mobile']:
                self.assertNotIn('manuscriptSpacing', profile)
                self.assertNotIn('textMeasure', profile)
        self.assertEqual(profiles['legacy-desktop']['textMeasure'], 640)
        self.assertEqual(profiles['legacy-desktop']['manuscriptSpacing'], 8)


if __name__ == '__main__':
    unittest.main()
