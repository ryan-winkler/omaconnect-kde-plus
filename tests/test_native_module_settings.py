"""Native feature rows, readback and target races with a private fake helper."""
import json
from pathlib import Path
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class NativeModuleSettingsTests(unittest.TestCase):
    def test_native_state_rows_and_exact_target_lifecycle(self):
        if not Path('/usr/lib/qt6/qml/QtTest/qmldir').is_file():
            self.skipTest('QtTest QML module absent')
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'native_module_settings_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            (fixture / 'commands.jsonl').write_text('')
            (plugin / 'scripts/native_settings.py').write_text('''import json,sys,time
from pathlib import Path
request=json.load(sys.stdin)
home=Path.home()
with (home/'module-requests.jsonl').open('a') as log:log.write(json.dumps(request)+'\\n')
peer=request['peerId']
path=home/('native-state-'+peer+'.json')
values=json.loads(path.read_text()) if path.exists() else {'kdeconnect_share':peer=='A','kdeconnect_clipboard':False,'native_mismatch':False,'native_unknown':False}
time.sleep(.25 if request['operation']=='set' else .08)
error='';state='observed'
if request['operation']=='read':enabled={key:values.get(key,False) for key in request['pluginIds']}
else:
 key=request['pluginId']
 if key=='native_unknown':state='unknown';error='submission-unknown';enabled={}
 elif key=='native_mismatch':error='readback-mismatch';enabled={key:values[key]}
 else:values[key]=request['enabled'];path.write_text(json.dumps(values));enabled={key:values[key]}
print(json.dumps({'state':state,'peerId':peer,'enabled':enabled,'error':error}))
sys.exit(0 if not error else 1)
''')

        def assert_modules(fixture, home, output, calls):
            self.assertIn('NATIVE_PASS native module settings', output)
            self.assertTrue(all(row['tool'] == 'fc-match' or (row['tool'] == 'hyprctl' and row['args'][:2] == ['-j', 'getoption']) for row in calls), calls)
            self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])
            requests = [json.loads(row) for row in (home / 'module-requests.jsonl').read_text().splitlines()]
            writes = [row for row in requests if row['operation'] == 'set']
            self.assertEqual([row['pluginId'] for row in writes], ['kdeconnect_share', 'kdeconnect_share', 'native_mismatch', 'native_unknown', 'kdeconnect_share'])
            self.assertTrue(all(row['peerId'] == 'A' for row in writes))
            self.assertEqual(requests[-1]['peerId'], 'C')
            self.assertFalse((home / '.config/kdeconnect').exists())

        runner.configure_fixture = configure
        runner.assert_fixture = assert_modules
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
