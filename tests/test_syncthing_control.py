"""Production Service with a private fake CLI; no live sync or configuration."""
import json
from pathlib import Path
import unittest
import test_native_ui as native_ui


class SyncthingControl(unittest.TestCase):
    def configure_fixture(self, fixture, plugin, home, fake_bin):
        program = fake_bin / 'syncthing'
        program.write_text('''#!/usr/bin/python3
import json, os, sys, time
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['NATIVE_COMMAND_LOG'], 'a') as out:
    out.write(json.dumps({'tool':'syncthing', 'args':args})+'\\n')
assert args[:2] == ['cli','config'] and args[2] == 'devices' and args[4] == 'paused'
device = args[3]; state = Path(os.environ['HOME']) / ('paused-' + device)
if args[5] == 'set':
    time.sleep(.08); state.write_text(args[6])
    if device.startswith('AAAAAAA'): raise SystemExit(1)
elif device.startswith('CCCCCCC'): print('unexpected')
elif device.startswith('DDDDDDD'): print('x'*5000)
elif device.startswith('EEEEEEE'): time.sleep(8)
else:
    time.sleep(.12)
    print(state.read_text() if state.exists() else 'true' if device.startswith('BBBBBBB') else 'false')
''')
        program.chmod(0o700)
        service = plugin / 'Service.qml'
        service.write_text(service.read_text().replace('/usr/bin/syncthing', str(program)))

    def assert_fixture(self, fixture, home, output, calls):
        self.assertIn('NATIVE_PASS syncthing', output)
        sync = [row['args'] for row in calls if row['tool'] == 'syncthing']
        # Both successful and failed-after-effect sets reconcile their same target.
        changes = [i for i, args in enumerate(sync) if args[5] == 'set']
        self.assertEqual(len(changes), 2)
        for changed in changes:
            self.assertEqual(sync[changed+1], sync[changed][:5]+['get'])
        self.assertTrue(sync[changes[1]+2][3].startswith('CCCCCCC'))
        self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()), [])

    def test_latest_selection_readback_bounds_and_recovery(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'syncthing_control_ui.qml'
        runner.force_offscreen = True
        runner.configure_fixture = self.configure_fixture
        runner.assert_fixture = self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
