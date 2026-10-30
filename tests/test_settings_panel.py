"""Independent native settings window, domain navigation and feature search."""
import json
from pathlib import Path
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class SettingsPanelTests(unittest.TestCase):
    def test_native_launch_feedback_uses_the_requested_device(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'native_launch_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            # Only a private stub runs; no native app or real session is reachable.
            discovery = plugin / 'scripts/discover_devices.sh'
            discovery.write_text(discovery.read_text().replace('kdeconnect_share,kdeconnect_battery', 'kdeconnect_share,kdeconnect_battery,kdeconnect_remotecommands'))
            (plugin / 'scripts/edit_remote_commands.py').write_text(
                'import json,sys,time\nfrom pathlib import Path\n'
                'request=json.loads(sys.stdin.readline())\n'
                'Path.home().joinpath("editor-request.json").write_text(json.dumps(request))\n'
                'count=Path.home()/"editor-count"\n'
                'number=int(count.read_text())+1 if count.exists() else 1\n'
                'count.write_text(str(number))\n'
                'time.sleep(0.6 if number==1 else 0.1)\n'
                'print(json.dumps({"state":"request_accepted","error":""} if number==1 else {"state":"failed","error":"submission-unknown"}))\n'
                'sys.exit(0 if number==1 else 1)\n'
            )
            (plugin / 'scripts/open_app.sh').write_text(
                '#!/bin/bash\n'
                'printf "%s\\n" "$1" >> "$HOME/native-targets"\n'
                '[[ -z "$2" ]] || printf "%s\\n" "$2" >> "$HOME/native-config-targets"\n'
                '/usr/bin/sleep 0.2\n'
                '[[ "$2" != kdeconnect_clipboard ]] || exit 69\n'
                '[[ "$1" != B ]] || exit 127\n'
            )

        def assert_launch(fixture, home, output, calls):
            self.assertIn('NATIVE_PASS native launch', output)
            self.assertEqual((home / 'native-targets').read_text().splitlines(), ['A', 'B', 'A', 'A', 'A', 'A', 'A'])
            self.assertEqual((home / 'native-config-targets').read_text().splitlines(), ['kdeconnect_runcommand', 'kdeconnect_clipboard'])
            self.assertEqual(json.loads((home / 'editor-request.json').read_text()), {'peerId': 'A'})
            self.assertTrue(all(row['tool'] in ('fc-match', 'hyprctl', 'dbus-monitor') for row in calls), calls)
            self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])

        runner.configure_fixture = configure
        runner.assert_fixture = assert_launch
        runner.test_actual_service_bar_panel_and_controls()

    def assert_fixture(self, fixture, home, output, calls):
        self.assertIn('SETTINGS_PASS', output, output)
        self.assertTrue(all(row["tool"] == "fc-match" or (row["tool"] == "hyprctl" and row["args"][:2] == ["-j", "getoption"]) for row in calls), calls)
        self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()), [])
        images=list(fixture.glob('settings-*.png'))
        self.assertEqual(len(images),12)

    def test_native_window_domains_search_and_return_flow(self):
        if not Path('/usr/lib/qt6/qml/QtTest/qmldir').is_file():
            self.skipTest('QtTest QML module absent')
        runner=native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='settings_panel_ui.qml'
        runner.force_offscreen=True
        runner.assert_fixture=self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()


if __name__=='__main__':unittest.main()
