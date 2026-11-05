"""Run the real controller and D-Bus monitor against a private owner."""
import json
import shutil
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class OwnerRecovery(unittest.TestCase):
    @unittest.skipUnless(shutil.which('dbus-monitor') and shutil.which('busctl'), 'D-Bus tools absent')
    def test_private_owner_loss_and_return(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'owner_recovery_ui.qml'
        runner.force_offscreen = True
        runner.real_dbus_monitor = True

        def configure(fixture, plugin, home, fake_bin):
            fake = fake_bin / 'fake'
            fake.write_text(fake.read_text().replace("if name == 'kdeconnect-cli':", """if name == 'kdeconnect-cli' and '--ring' in sys.argv:
 time.sleep(1.65)
 Path.home().joinpath('old-action-completed').touch()
 raise SystemExit(0)
if name == 'kdeconnect-cli':"""))
            (fake_bin / 'busctl').symlink_to(shutil.which('busctl'))
            scan = plugin / 'scripts/discover_devices.sh'
            scan.write_text('''#!/bin/bash
set -eu
[[ $# == 0 ]] || exit 64
printf '%s\\n' scan >> "$HOME/owner-scans"
[[ $(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.kde.kdeconnect) == "b true" ]] || exit 69
''' + '\n'.join(scan.read_text().splitlines()[1:]).replace('kdeconnect_battery', 'kdeconnect_battery,kdeconnect_findmyphone') + '\n')
            session = fixture / 'session.py'
            session.write_text(session.read_text().replace('GLib.timeout_add(30, done)', '''def change_owner():
    request = Path.home() / 'owner-request'
    if not request.exists():
        return GLib.SOURCE_CONTINUE
    change = request.read_text()
    if change not in ('release', 'acquire'):
        return GLib.SOURCE_CONTINUE
    request.unlink()
    method = 'ReleaseName' if change == 'release' else 'RequestName'
    args = GLib.Variant('(s)', ('org.kde.kdeconnect',)) if change == 'release' else GLib.Variant('(su)', ('org.kde.kdeconnect', 0))
    bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', method, args, GLib.VariantType.new('(u)'), Gio.DBusCallFlags.NONE, 1000, None)
    return GLib.SOURCE_CONTINUE

GLib.timeout_add(20, change_owner)
GLib.timeout_add(30, done)'''))

        def check(fixture, home, output, calls):
            self.assertIn('NATIVE_PASS owner recovery', output)
            self.assertEqual((home / 'owner-scans').read_text().splitlines(), ['scan'] * 3)
            self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])
            self.assertTrue((home / 'old-action-completed').exists())
            self.assertEqual([row for row in calls if row['tool'].startswith('kdeconnect')],
                             [{'tool': 'kdeconnect-cli', 'args': ['-d', 'B', '--ring']}])

        runner.configure_fixture = configure
        runner.assert_fixture = check
        runner.test_actual_service_bar_panel_and_controls()
