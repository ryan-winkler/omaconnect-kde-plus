"""Visibility saves use one bounded native settings API; providers stay untouched."""
import json
from pathlib import Path
import sys
import shutil
import unittest
from unittest.mock import patch

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui

SCRIPTS = Path(__file__).parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
try:
    import network_preferences as preferences
finally:
    sys.path.pop(0)


class NetworkPreferences(unittest.TestCase):
    def test_only_exact_visibility_keys_and_boolean_values_reach_native_api(self):
        for key in preferences.KEYS:
            for enabled in (True, False):
                with patch.object(preferences, 'bounded_command', return_value=b'ok\n') as command:
                    self.assertTrue(preferences.save({'key':key, 'enabled':enabled})['ok'])
                    self.assertEqual(command.call_args.args[0], ['/usr/bin/omarchy-shell', 'shell', 'setBarWidget', 'ryan.omaconnect', key, 'true' if enabled else 'false', '{}'])
        for request in (None, {}, {'key':[], 'enabled':True}, {'key':'bth-on', 'enabled':True}, {'key':'showTailscale', 'enabled':True}, {'key':'showDeviceTypeIcons', 'enabled':False}, {'key':'showTroubleshooting', 'enabled':True}, {'key':'networkTailscaleEnabled', 'enabled':'true'}, {'key':'networkBthEnabled', 'enabled':True, 'command':'anything'}):
            with patch.object(preferences, 'bounded_command') as command:
                self.assertFalse(preferences.save(request)['ok'])
                command.assert_not_called()

    def test_reviewed_strings_use_json_arguments_and_reject_unsafe_values(self):
        samples = [('defaultPingMessage', 'Hello \"friend\"\nNext\tline'), ('defaultPingMessage', 'x' * 4096), ('bthHelperPath', ''), ('bthHelperPath', '/home/user/tools/remote-access-mode')]
        for key, value in samples:
            with patch.object(preferences, 'bounded_command', return_value=b'ok\n') as command:
                self.assertTrue(preferences.save({'key':key, 'value':value})['ok'])
                self.assertEqual(json.loads(command.call_args.args[0][-2]), value)
        for key, value in [('defaultPingMessage', 'x' * 4097), ('defaultPingMessage', 'bad\x00value'), ('bthHelperPath', 'relative/remote-access-mode'), ('bthHelperPath', '/home/../remote-access-mode'), ('bthHelperPath', '/home/user/other'), ('bthHelperPath', '/home/\nremote-access-mode')]:
            with patch.object(preferences, 'bounded_command') as command:
                self.assertFalse(preferences.save({'key':key, 'value':value})['ok'])
                command.assert_not_called()
        for request in ({'key':'bthHelperPath','enabled':True}, {'key':'showBarBattery','value':'true'}, {'key':'defaultPingMessage','value':'text','enabled':True}):
            self.assertFalse(preferences.save(request)['ok'])

    def test_preference_owner_matches_fork_and_excludes_original(self):
        manifest = json.loads((SCRIPTS.parent / "manifest.json").read_text())
        self.assertEqual(manifest["id"], "ryan.omaconnect")
        self.assertNotEqual(manifest["id"], "omaconnect")
        self.assertTrue((preferences.KEYS | preferences.STRING_KEYS).issubset(manifest["settings"]))

    def test_unknown_and_timed_out_settings_do_not_claim_saved(self):
        for reply in (b'unknown\n', b'', b'ok\nprivate detail', b'error'):
            with patch.object(preferences, 'bounded_command', return_value=reply):
                self.assertFalse(preferences.save({'key':'networkBthEnabled', 'enabled':True})['ok'])
        with patch.object(preferences, 'bounded_command', side_effect=preferences.AddressError('address-timeout')):
            self.assertFalse(preferences.save({'key':'networkBthEnabled', 'enabled':True})['ok'])

    def configure_fixture(self, fixture, plugin, home, fake_bin):
        # The base integration substitutes address reconciliation. This focused
        # scenario retains the real bounded-command boundary under a new name.
        shutil.copyfile(SCRIPTS/'manage_addresses.py', plugin/'scripts/network_preference_boundary.py')
        helper = plugin/'scripts/network_preferences.py'
        helper.write_text(helper.read_text().replace('from manage_addresses import', 'from network_preference_boundary import'))
        fake = fake_bin/'fake'
        text = fake.read_text().replace("elif name == 'omarchy-shell': raise SystemExit(0)", "elif name == 'omarchy-shell': print('unknown' if 'false' in sys.argv else 'ok')")
        fake.write_text(text)

    def assert_fixture(self, fixture, home, output, calls):
        self.assertIn('PREFERENCES_PASS', output, output)
        writes = [r['args'] for r in calls if r['tool'] == 'omarchy-shell']
        self.assertEqual(writes, [['shell', 'setBarWidget', 'ryan.omaconnect', 'networkTailscaleEnabled', 'true', '{}'], ['shell', 'setBarWidget', 'ryan.omaconnect', 'networkTailscaleEnabled', 'false', '{}']])
        self.assertFalse(any(r['tool'] in ('kdeconnect-cli', 'nmcli', 'remote-access-mode') for r in calls), calls)
        self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()), [])

    def test_native_switches_follow_saved_state_and_failed_save_preserves_it(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'network_preferences_ui.qml'
        runner.force_offscreen = True
        runner.configure_fixture = self.configure_fixture
        runner.assert_fixture = self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
