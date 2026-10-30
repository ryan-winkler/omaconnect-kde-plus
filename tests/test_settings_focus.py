"""Tab navigation reveals controls in the minimum-size native Settings window."""
import json
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class SettingsFocusTests(unittest.TestCase):
    def test_tab_and_backtab_reveal_each_domain_without_moving_focus(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'settings_focus_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            # Record keyboard activation in private state. No save reaches the
            # user's bar or configuration.
            (plugin / 'scripts/network_preferences.py').write_text(
                'import json,sys\nfrom pathlib import Path\n'
                'request=json.load(sys.stdin)\n'
                'with (Path.home()/"focus-actions.jsonl").open("a") as out: out.write(json.dumps(request)+"\\n")\n'
                'print(json.dumps({"ok":True,"message":"Setting saved."}))\n'
            )

        def assert_focus(fixture, home, output, calls):
            for page in ('Appearance', 'Connections', 'Quick actions', 'Device features'):
                self.assertIn('FOCUS_PASS ' + page + ' Tab and Shift+Tab', output)
            self.assertTrue(all(call['tool'] == 'fc-match' or (call['tool'] == 'hyprctl' and call['args'][:2] == ['-j', 'getoption']) for call in calls), calls)
            self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])
            actions = [json.loads(row) for row in (home / 'focus-actions.jsonl').read_text().splitlines()]
            self.assertEqual([row['key'] for row in actions], ['syncthingStartExpanded', 'networkWireguardEnabled', 'quickActionsOrder', 'showRemoteCommands'])

        runner.configure_fixture = configure
        runner.assert_fixture = assert_focus
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
