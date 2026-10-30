"""Launcher and device action feedback remain independent with fake providers."""
import json
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class QuickShareLaunchTests(unittest.TestCase):
    def test_native_concurrent_device_action_and_launcher_results(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'quick_share_launch_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            discovery = plugin / 'scripts/discover_devices.sh'
            discovery.write_text(discovery.read_text().replace(
                'kdeconnect_share,kdeconnect_battery',
                'kdeconnect_share,kdeconnect_battery,kdeconnect_ping'))
            (plugin / 'scripts/send_text.py').write_text(
                'import json,sys,time\njson.loads(sys.stdin.readline())\n'
                'time.sleep(1)\nprint(json.dumps({"state":"request_accepted","error":""}))\n')
            (plugin / 'scripts/open_quick_share.py').write_text(
                'import sys,time\nfrom pathlib import Path\n'
                'if sys.argv[1:] == ["--check"]: raise SystemExit(0)\n'
                'assert sys.argv[1:] == ["--open"]\n'
                'marker=Path.home()/"quick-share-launches"\n'
                'count=int(marker.read_text())+1 if marker.exists() else 1\n'
                'marker.write_text(str(count))\ntime.sleep(.25)\n'
                'raise SystemExit(0 if count == 1 else 1)\n')

        def assert_isolation(fixture, home, output, calls):
            self.assertIn('NATIVE_PASS Quick Share feedback isolation', output)
            self.assertEqual((home / 'quick-share-launches').read_text(), '2')
            self.assertTrue(all(row['tool'] in ('fc-match', 'hyprctl', 'dbus-monitor') for row in calls), calls)
            self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])

        runner.configure_fixture = configure
        runner.assert_fixture = assert_isolation
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
