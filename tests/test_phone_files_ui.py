"""Run the real phone-files controller and UI against an owned fake helper."""
import json
from pathlib import Path
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class PhoneFilesUi(unittest.TestCase):
    def test_native_capture_choices_late_results_cancel_and_draft_preservation(self):
        """Run product QML with a fake storage helper and check capture, cancellation and draft preservation."""
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'phone_files_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            path = plugin / 'scripts/discover_devices.sh'
            path.write_text(path.read_text().replace('kdeconnect_share,kdeconnect_battery',
                                                     'kdeconnect_share,kdeconnect_battery,kdeconnect_sftp'))
            (plugin / 'scripts/browse_phone_files.py').write_text('''import json,signal,sys,time
from pathlib import Path
home=Path.home()
request=json.loads(sys.stdin.readline())
counter=home/'browse-counter'
number=int(counter.read_text()) if counter.exists() else 0
if request['operation']=='prepare': number+=1;counter.write_text(str(number))
with (home/'browse.jsonl').open('a') as out: out.write(json.dumps({'number':number,**request})+'\\n')
peer=request['peerId']
def location(index):
 return {'peerId':peer,'providerOwner':':1.42','path':'/owned/native/'+peer+'/folder'+str(index),
  'name':'<b>Second storage</b>' if index else 'Shared storage','mountPath':'/owned/native/'+peer,
  'mountIdentity':'a'*64,'rootIdentity':str(index)*64,'advertisements':'b'*64}
if request['operation']=='prepare':
 if number in (3,6,9): signal.signal(signal.SIGTERM,signal.SIG_IGN);time.sleep(.65)
 else: time.sleep(.15)
 if number==8: print('x'*16385,flush=True);time.sleep(.1);raise SystemExit(1)
 result={'state':'prepared','error':'','peerId':peer,'locations':[location(0)]}
 if number in (2,5): result['locations'].append(location(1))
 if number==7: result['peerId']='Other_phone'
 if number==10: result={'state':'failed','error':'mount-not-ready'}
else:
 time.sleep(.15)
 result={'state':'failed','error':'opener-unavailable'} if number==4 else {'state':'opened','error':''}
print(json.dumps(result),flush=True)
raise SystemExit(1 if result['state']=='failed' else 0)
''')

        def check(fixture, home, output, calls):
            """Verify selected-folder requests and reject unintended file submissions or shell launches."""
            self.assertIn('NATIVE_PASS phone files', output)
            records = [json.loads(line) for line in (home/'browse.jsonl').read_text().splitlines()]
            self.assertEqual([row['number'] for row in records if row['operation']=='prepare'], list(range(1, 11)))
            opened = [row for row in records if row['operation']=='open']
            self.assertEqual([(row['number'], row['peerId']) for row in opened], [(1,'A'),(2,'A'),(4,'B')])
            self.assertTrue(opened[1]['location']['path'].endswith('/folder1'))
            self.assertFalse(any(row['tool']=='kdeconnect-share' for row in calls))
            self.assertFalse(any(row['tool']=='omarchy-shell' for row in calls))

        runner.configure_fixture = configure
        runner.assert_fixture = check
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
