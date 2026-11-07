"""Shared native daily picker, identity guards and existing file-review ownership."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class DeviceSwitcherTests(unittest.TestCase):
    def test_daily_native_picker_keyboard_identity_and_collapsed_warnings(self):
        """Exercise the picker, trust handoff and owner-pinned Unpair with fake providers."""
        runner=native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='daily_device_picker_ui.qml'
        runner.force_offscreen=True
        def configure(fixture,plugin,home,fake_bin):
            """Return distinct native readbacks and record the launcher arguments."""
            fake = fake_bin/'fake'
            fake.write_text(fake.read_text().replace("if name == 'kdeconnect-cli':", """if name == 'busctl':
 if sys.argv[-1] == 'isPaired':
  print('b true')
  raise SystemExit(0)
 if 'GetNameOwner' in sys.argv:
  print('s ":1.42"')
  raise SystemExit(0)
 if sys.argv[-1] == 'unpair':
  time.sleep(.3)
  if sys.argv[-3].endswith('/A'):
   Path.home().joinpath('a-unpaired').touch()
  elif Path.home().joinpath('pairing-return').exists():
   Path.home().joinpath('b-disappeared').touch()
  raise SystemExit(0)
if name == 'kdeconnect-cli':"""))
            (fake_bin/'busctl').symlink_to(fake)
            (fake_bin/'gdbus').symlink_to(fake)
            (home / "pairing-launch-state").write_text("idle")
            (plugin/'scripts/open_app.sh').write_text("""#!/bin/bash
exec python3 -c 'import json,os,sys,time
from pathlib import Path
with open(os.environ["NATIVE_COMMAND_LOG"],"a") as log:
    log.write(json.dumps({"tool":"open-app","args":sys.argv[1:]})+"\\n")
if Path.home().joinpath("a-unpaired").exists():
    Path.home().joinpath("pairing-launch-state").write_text("launching")
    for _ in range(100):
        if Path.home().joinpath("return-read-started").exists():
            break
        time.sleep(.02)
    else:
        sys.exit(1)
    Path.home().joinpath("pairing-return").touch()
' "$@"
""")
            scan = plugin/'scripts/discover_devices.sh'
            scan.write_text(r"""#!/bin/bash
state_suffix=$'\t\t-1\tfalse\tfalse\t\t\tfalse\t{"pairingKnown":true,"reachabilityKnown":true,"requestKnown":true}'
unknown_peer=$'DEVICE\tB\tOther phone\tlaptop\tfalse\ttrue\t65\tfalse\tkdeconnect_share,kdeconnect_battery\t\t-1\tfalse\tfalse\t\t\tfalse\t{"pairingKnown":false,"reachabilityKnown":true,"requestKnown":false}'
printf '%s\n' 'CUSTOM_ADDRESSES_READY' $'DEVICE_OWNER\t:1.42'
unpaired_a=$'DEVICE\tA\tOriginal phone\tphone\tfalse\ttrue\t80\tfalse\tkdeconnect_share,kdeconnect_battery'"$state_suffix"
if [[ -f "$HOME/b-disappeared" ]]; then
    printf '%s\n' "$unpaired_a" $'DEVICE_SCAN\t1\t1'
    exit 0
fi
if [[ -f "$HOME/pairing-return" ]]; then
    printf 'after:%s:%s\n' "$#" "$*" >> "$HOME/return-scans"
    printf '%s\n' $'DEVICE\tB\tOther phone\tlaptop\ttrue\tfalse\t65\tfalse\tkdeconnect_share,kdeconnect_battery'"$state_suffix" $'DEVICE_SCAN\t3\t1'
    exit 0
fi
if [[ $(<"$HOME/pairing-launch-state") == launching ]]; then
    printf 'before:%s:%s\n' "$#" "$*" >> "$HOME/return-scans"
    : > "$HOME/return-read-started"
    sleep .35
fi
if [[ -f "$HOME/a-unpaired" ]]; then
    printf '%s\n' "$unpaired_a" "$unknown_peer" \
        $'DEVICE\tC\tConnected phone\tphone\ttrue\ttrue\t90\tfalse\tkdeconnect_share,kdeconnect_battery'"$state_suffix" \
        $'DEVICE\tD\tPaired phone\tphone\ttrue\tfalse\t-1\tfalse\tkdeconnect_share\t\t-1\tfalse\tfalse\t\t\tfalse\t{"pairingKnown":true,"reachabilityKnown":false,"requestKnown":true}' \
        $'DEVICE_SCAN\t5\t4'
    exit 0
fi
printf '%s\n' \
    $'DEVICE\tA\tOriginal phone\tphone\ttrue\ttrue\t80\tfalse\tkdeconnect_share,kdeconnect_battery'"$state_suffix" \
    $'DEVICE\tB\tOther phone\tlaptop\ttrue\ttrue\t65\tfalse\tkdeconnect_share,kdeconnect_battery'"$state_suffix" \
    $'DEVICE_SCAN\t2\t2'
""")
            (plugin/'scripts/send_text.py').write_text('''import json
import sys
import time

request = json.loads(sys.stdin.readline())
if request["text"] in ("Fixture pending switch", "Fixture same text"):
    time.sleep(2)
if request["text"] == "Fixture failed":
    print(json.dumps({"state": "failed", "error": "submission-failed"}))
    sys.exit(1)
if request["text"] == "Fixture unknown":
    print(json.dumps({"state": "failed", "error": "submission-unknown"}))
    sys.exit(1)
print(json.dumps({"state": "request_accepted"}))
''')
        def assert_picker(fixture,home,output,calls):
            """Require list-only handoffs and exact, explicitly confirmed Unpair calls."""
            self.assertIn('DAILY_PICKER_PASS',output)
            expected_unpairs = []
            for peer in ('B', 'A', 'B'):
                path = f'/modules/kdeconnect/devices/{peer}'
                expected_unpairs.extend([
                    ['--user', '--timeout=2', '--auto-start=no', 'get-property', ':1.42',
                     path, 'org.kde.kdeconnect.device', 'isPaired'],
                    ['--user', '--timeout=2', '--auto-start=no', 'call',
                     'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                     'GetNameOwner', 's', 'org.kde.kdeconnect'],
                    ['--user', '--timeout=5', '--auto-start=no', 'call', ':1.42',
                     path, 'org.kde.kdeconnect.device', 'unpair'],
                ])
            self.assertEqual([row['args'] for row in calls if row['tool'] == 'busctl'],
                             expected_unpairs)
            self.assertEqual([row['args'] for row in calls if row['tool'] == 'open-app'], [[], [], [], []])
            self.assertEqual((home/'return-scans').read_text().splitlines(), ['before:0:', 'after:0:'])
            self.assertFalse(any(row['tool'] in ('gdbus','kdeconnect-cli','nmcli','omarchy-shell','remote-access-mode') for row in calls),calls)
            self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()),[])
        original_run=native_ui.subprocess.run
        def isolated_run(command,*args,**kwargs):
            if command and command[0]=='/usr/bin/bwrap':
                command=list(command)
                fixture=Path(command[command.index('--chdir')+1])
                at=command.index('/usr/bin/dbus-run-session')
                command[at:at]=['--ro-bind',str(fixture/'bin/fake'),'/usr/bin/busctl']
            return original_run(command,*args,**kwargs)
        runner.configure_fixture=configure
        runner.assert_fixture=assert_picker
        with patch.object(native_ui.subprocess,'run',side_effect=isolated_run):
            runner.test_actual_service_bar_panel_and_controls()
