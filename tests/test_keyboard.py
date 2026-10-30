"""Actual Qt key events in the existing offscreen sandbox; no real actions."""
import json
from pathlib import Path
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class KeyboardUi(unittest.TestCase):
    def configure_fixture(self, fixture, plugin, home, fake_bin):
        helper = home / '.local/bin/remote-access-mode'
        helper.unlink()
        status = dict(schema_version=1, configured=True, profile_safe=True,
                      control_valid=True, nm_control=True, pending=False,
                      control_mode='auto', connection_state='inactive', error=None,
                      last_report=dict(phase='ready', age_seconds=0, control_mode='auto'))
        helper.write_text(
            '#!/usr/bin/python3\nimport json,os,sys\n'
            'with open(os.environ["NATIVE_COMMAND_LOG"],"a") as out:\n'
            ' out.write(json.dumps({"tool":"remote-access-mode","args":sys.argv[1:]})+"\\n")\n'
            'if sys.argv[1:] != ["control-status"]: raise SystemExit(98)\n'
            'print(' + repr(json.dumps(status)) + ')\n')
        helper.chmod(0o700)

    def assert_fixture(self, fixture, home, output, calls):
        self.assertIn('KEYBOARD_PASS', output, output)
        self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])
        self.assertFalse(any(row['tool'] in ('kdeconnect-cli', 'kdeconnect-share', 'nmcli', 'omarchy-shell')
                             for row in calls), calls)
        modes = [row for row in calls if row['tool'] == 'remote-access-mode']
        self.assertTrue(modes, calls)
        self.assertTrue(all(row['args'] == ['control-status'] for row in modes), modes)
        self.assertFalse((home / '.config/Omaconnect.plus/appearance.json').exists())

    def test_real_key_events_reach_views_bth_and_editors(self):
        qt_test = Path('/usr/lib/qt6/qml/QtTest/qmldir')
        if not qt_test.is_file():
            self.skipTest('QtTest QML event module absent')
        # Composition avoids collecting the base class's native test a second time.
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'keyboard_ui.qml'
        runner.force_offscreen = True
        runner.configure_fixture = self.configure_fixture
        runner.assert_fixture = self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
