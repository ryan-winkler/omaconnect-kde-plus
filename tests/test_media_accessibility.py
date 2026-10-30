"""Native media Tab, key, accessibility and disabled dispatch; fake service only."""
import json
import unittest
import test_native_ui as native_ui


class MediaAccessibility(unittest.TestCase):
    def configure_fixture(self, fixture, plugin, home, fake_bin):
        (fixture/'commands.jsonl').write_text('')

    def assert_fixture(self, fixture, home, output, calls):
        self.assertIn('MEDIA_ACCESSIBILITY_PASS', output, output)
        self.assertTrue(all(row["tool"] in ("fc-match", "hyprctl") for row in calls), calls)
        self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()), [])

    def test_tab_keys_accessible_press_and_disabled_controls(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'media_accessibility_ui.qml'
        runner.force_offscreen = True
        runner.configure_fixture = self.configure_fixture
        runner.assert_fixture = self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()
