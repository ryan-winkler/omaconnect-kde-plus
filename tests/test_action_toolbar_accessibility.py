"""Actual native toolbar semantics and key dispatch, with no provider actions."""
import json
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class ActionToolbarAccessibility(unittest.TestCase):
    def configure_fixture(self, fixture, plugin, home, fake_bin):
        # A component-only scenario need not invoke any command. Keep the
        # shared harness receipt present, so absence is asserted explicitly.
        (fixture / 'commands.jsonl').write_text('')

    def assert_fixture(self, fixture, home, output, calls):
        self.assertIn('ACTION_TOOLBAR_ACCESSIBILITY_PASS', output, output)
        self.assertNotIn('Accessible must be attached to an Item', output, output)
        self.assertFalse(any(row['tool'] in (
            'kdeconnect-cli', 'kdeconnect-share', 'nmcli', 'remote-access-mode', 'omarchy-shell'
        ) for row in calls), calls)
        self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])

    def test_native_daily_actions_role_help_tab_enter_space_and_press(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'action_toolbar_accessibility_ui.qml'
        runner.force_offscreen = True
        runner.configure_fixture = self.configure_fixture
        runner.assert_fixture = self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
