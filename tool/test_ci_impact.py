"""Keep affected-surface selection proportional without dropping SDK gates."""

import unittest

from ci_impact import gates


class ImpactTests(unittest.TestCase):
    def test_manual_runs_and_ci_changes_keep_all_gates(self):
        expected = {'compat-minimum', 'compat-high', 'downgrade', 'demo', 'package'}
        for files in (None, ['.github/workflows/dart.yml'], ['tool/ci_impact.py']):
            with self.subTest(files=files):
                self.assertEqual(expected, gates(files))

    def test_docs_and_local_policy_do_not_bootstrap_an_sdk(self):
        self.assertEqual(set(), gates([
            'README.md', 'demo/README.md', 'example/README.md',
            '.agents/skills/flutter-project/SKILL.md', '.gtm/quality.json',
        ]))

    def test_public_implementation_keeps_every_contract(self):
        self.assertEqual(gates(None), gates(['lib/src/auto_size_text.dart']))

    def test_behavior_tests_keep_both_sdks_without_native_builds(self):
        self.assertEqual({'compat-minimum', 'compat-high'}, gates([
            'test/effective_text_configuration_test.dart',
        ]))

    def test_native_demo_changes_stay_in_the_demo_lane(self):
        self.assertEqual({'demo'}, gates(['demo/android/app/build.gradle.kts']))

    def test_archive_and_font_assets_keep_archive_validation(self):
        self.assertEqual({'package'}, gates(['.pubignore']))
        self.assertEqual({'compat-minimum', 'compat-high', 'package'}, gates([
            'test/assets/fonts/auto_size_metric_naskh_locl.ttf',
        ]))


if __name__ == '__main__':
    unittest.main()
