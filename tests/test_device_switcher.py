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
        runner=native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='daily_device_picker_ui.qml'
        runner.force_offscreen=True
        def configure(fixture,plugin,home,fake_bin):
            fake = fake_bin/'fake'
            fake.write_text(fake.read_text().replace("if name == 'kdeconnect-cli':",
                                                     "if name == 'kdeconnect-cli':\n if '--pair' in sys.argv: raise SystemExit(1)"))
            (fake_bin/'busctl').symlink_to(fake)
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
            self.assertIn('DAILY_PICKER_PASS',output)
            self.assertEqual([row['args'] for row in calls if row['tool'] == 'kdeconnect-cli'],
                             [['-d', 'B', '--unpair'], ['-d', 'A', '--unpair'], ['-d', 'C', '--pair']])
            self.assertFalse(any(row['tool'] in ('nmcli','omarchy-shell','remote-access-mode') for row in calls),calls)
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
