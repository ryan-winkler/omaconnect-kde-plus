"""Run the real controller and D-Bus monitor against a private owner."""
import json
import shutil
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


@unittest.skipUnless(shutil.which('dbus-monitor') and shutil.which('busctl'), 'D-Bus tools absent')
class OwnerRecovery(unittest.TestCase):
    def test_private_owner_loss_and_return(self):
        """Report uncertainty when the interrupted device remains selected."""
        self.run_owner_recovery(switch_before_loss=False)

    def test_interruption_does_not_follow_selection(self):
        """Suppress the interrupted device's banner on another selected peer."""
        self.run_owner_recovery(switch_before_loss=True)

    def run_owner_recovery(self, *, switch_before_loss):
        """Exercise provider turnover on a private bus while a reviewed action is pending."""
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'owner_recovery_ui.qml'
        runner.force_offscreen = True
        runner.real_dbus_monitor = True

        def configure(fixture, plugin, home, fake_bin):
            """Delay the old owner's Unpair until after a fresh owner has appeared."""
            (home / "old-action-state").write_text("idle")
            if switch_before_loss:
                qml = fixture / 'shell.qml'
                qml.write_text(qml.read_text().replace(
                    'readonly property bool switchBeforeLoss: false',
                    'readonly property bool switchBeforeLoss: true',
                ))
            fake = fake_bin / 'fake'
            fake.write_text(fake.read_text().replace("if name == 'kdeconnect-cli':", """if name == 'busctl':
 if sys.argv[-1] == 'isPaired':
  print('b true')
  raise SystemExit(0)
 if 'GetNameOwner' in sys.argv:
  os.execv('/usr/bin/busctl', ['busctl', *sys.argv[1:]])
 if sys.argv[-1] == 'unpair':
  Path.home().joinpath('old-action-state').write_text('started')
  time.sleep(1.65)
  Path.home().joinpath('old-action-completed').touch()
  raise SystemExit(0)
if name == 'kdeconnect-cli':"""))
            (fake_bin / 'busctl').symlink_to(fake)
            scan = plugin / 'scripts/discover_devices.sh'
            scan.write_text(r"""#!/bin/bash
set -eu
[[ $# == 0 ]] || exit 64
printf '%s\n' scan >> "$HOME/owner-scans"
owner_json=$(/usr/bin/busctl --user --json=short call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s org.kde.kdeconnect) || exit 69
owner=$(printf '%s' "$owner_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"][0])')
printf '%s\n' "$owner" >> "$HOME/owner-identities"
if [[ -f "$HOME/owner-request" && $(<"$HOME/owner-request") == pair-signal ]]; then
    printf '%s:%s\n' "$#" "$*" >> "$HOME/signal-scans"
    : > "$HOME/signal-scan-started"
    sleep .9
    : > "$HOME/signal-scan-finished"
elif [[ -f "$HOME/signal-scan-started" ]]; then
    printf '%s:%s\n' "$#" "$*" >> "$HOME/signal-scans"
fi
state_suffix=$'\t\t-1\tfalse\tfalse\t\t\tfalse\t{"pairingKnown":true,"reachabilityKnown":true,"requestKnown":true}'
printf '%s\n' 'CUSTOM_ADDRESSES_READY'
printf 'DEVICE_OWNER\t%s\n' "$owner"
printf '%s\n' \
    $'DEVICE\tA\tOriginal phone\tphone\ttrue\ttrue\t80\tfalse\tkdeconnect_share,kdeconnect_battery'"$state_suffix" \
    $'DEVICE\tB\tOther phone\tlaptop\ttrue\ttrue\t65\tfalse\tkdeconnect_share,kdeconnect_battery'"$state_suffix" \
    $'DEVICE_SCAN\t2\t2'
""")
            session = fixture / 'session.py'
            session.write_text(session.read_text().replace('GLib.timeout_add(30, done)', '''replacement_owner = None

def change_owner():
    global replacement_owner
    request = Path.home() / 'owner-request'
    if not request.exists():
        return GLib.SOURCE_CONTINUE
    change = request.read_text()
    if change == 'pair-signal':
        if not Path.home().joinpath('signal-scan-started').exists():
            return GLib.SOURCE_CONTINUE
        request.unlink()
        assert not Path.home().joinpath('signal-scan-finished').exists()
        for _ in range(2):
            replacement_owner.emit_signal(None, '/modules/kdeconnect/devices/B',
                'org.kde.kdeconnect.device', 'pairStateChanged', GLib.Variant('(i)', (1,)))
        return GLib.SOURCE_CONTINUE
    if change not in ('release', 'acquire'):
        return GLib.SOURCE_CONTINUE
    request.unlink()
    method = 'ReleaseName' if change == 'release' else 'RequestName'
    args = GLib.Variant('(s)', ('org.kde.kdeconnect',)) if change == 'release' else GLib.Variant('(su)', ('org.kde.kdeconnect', 0))
    connection = bus
    if change == 'acquire':
        replacement_owner = Gio.DBusConnection.new_for_address_sync(
            os.environ['DBUS_SESSION_BUS_ADDRESS'],
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
            None, None,
        )
        connection = replacement_owner
    connection.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', method, args, GLib.VariantType.new('(u)'), Gio.DBusCallFlags.NONE, 1000, None)
    return GLib.SOURCE_CONTINUE

GLib.timeout_add(20, change_owner)
GLib.timeout_add(30, done)'''))

        def check(fixture, home, output, calls):
            """Require one dispatch and no extra readback after owner turnover."""
            scenario = 'switched' if switch_before_loss else 'retained'
            self.assertIn(f'NATIVE_PASS owner recovery {scenario}', output)
            scans = 3 if switch_before_loss else 5
            self.assertEqual((home / 'owner-scans').read_text().splitlines(), ['scan'] * scans)
            if not switch_before_loss:
                self.assertEqual((home / 'signal-scans').read_text().splitlines(), ['0:', '0:'])
            self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])
            self.assertTrue((home / 'old-action-completed').exists())
            owner, *replacement_reads = (home / 'owner-identities').read_text().splitlines()
            self.assertNotEqual(owner, replacement_reads[0])
            self.assertEqual(replacement_reads, [replacement_reads[0]] * (scans - 2))
            path = '/modules/kdeconnect/devices/B'
            self.assertEqual([row for row in calls if row['tool'] in ('busctl', 'kdeconnect-cli')], [
                {'tool': 'busctl', 'args': ['--user', '--timeout=2', '--auto-start=no',
                 'get-property', owner, path, 'org.kde.kdeconnect.device', 'isPaired']},
                {'tool': 'busctl', 'args': ['--user', '--timeout=2', '--auto-start=no',
                 'call', 'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                 'GetNameOwner', 's', 'org.kde.kdeconnect']},
                {'tool': 'busctl', 'args': ['--user', '--timeout=5', '--auto-start=no',
                 'call', owner, path, 'org.kde.kdeconnect.device', 'unpair']},
            ])

        runner.configure_fixture = configure
        runner.assert_fixture = check
        runner.test_actual_service_bar_panel_and_controls()
