"""Tab navigation reveals controls in the minimum-size native Settings window."""
import json
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class SettingsFocusTests(unittest.TestCase):
    def run_domain(self, page_index, page_name, expected_key):
        """Keep each complete traversal within one bounded native session."""
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'settings_focus_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            # Each domain gets a fresh private process and its own deadline.
            # The traversal itself is unchanged; do not shorten focus cycles.
            fixture_qml = fixture / 'shell.qml'
            source = fixture_qml.read_text()
            self.assertIn('property int page: 0', source)
            fixture_qml.write_text(source.replace('property int page: 0', 'property int page: ' + str(page_index), 1))
            # Record keyboard activation in private state. No save reaches the
            # user's bar or configuration.
            (plugin / 'scripts/network_preferences.py').write_text(
                'import json,sys\nfrom pathlib import Path\n'
                'request=json.load(sys.stdin)\n'
                'with (Path.home()/"focus-actions.jsonl").open("a") as out: out.write(json.dumps(request)+"\\n")\n'
                'print(json.dumps({"ok":True,"message":"Setting saved."}))\n'
            )

        def assert_focus(fixture, home, output, calls):
            self.assertIn('FOCUS_PASS ' + page_name + ' Tab and Shift+Tab', output)
            self.assertIn('FOCUS_WRAP_PASS ' + page_name + ' Close to Device and back', output)
            self.assertTrue(all(call['tool'] == 'fc-match' or (call['tool'] == 'hyprctl' and call['args'][:2] == ['-j', 'getoption']) for call in calls), calls)
            self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])
            actions = [json.loads(row) for row in (home / 'focus-actions.jsonl').read_text().splitlines()]
            self.assertEqual([row['key'] for row in actions], [expected_key])

        runner.configure_fixture = configure
        runner.assert_fixture = assert_focus
        runner.test_actual_service_bar_panel_and_controls()

    def test_appearance_tab_and_backtab_reveal_without_moving_focus(self):
        self.run_domain(0, 'Appearance', 'showBarBattery')

    def test_connections_tab_and_backtab_reveal_without_moving_focus(self):
        self.run_domain(1, 'Connections', 'networkWireguardEnabled')

    def test_quick_actions_tab_and_backtab_reveal_without_moving_focus(self):
        self.run_domain(2, 'Quick actions', 'quickActionsOrder')

    def test_device_features_tab_and_backtab_reveal_without_moving_focus(self):
        self.run_domain(3, 'Device features', 'showRemoteCommands')


if __name__ == '__main__':
    unittest.main()
