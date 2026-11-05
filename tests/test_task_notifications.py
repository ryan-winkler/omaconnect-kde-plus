"""Native notice privacy and final-event checks. All services/state are owned fakes."""
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

if __package__:
    from . import test_native_ui as native_ui
    from .test_sharing_modes import block
else:
    import test_native_ui as native_ui
    from test_sharing_modes import block

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('task_notification', ROOT/'scripts/task_notification.py')
notice = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notice)


class TaskNoticeTests(unittest.TestCase):
    def test_unwritten_notice_rechecks_privacy_and_surface_generation(self):
        """Discard unwritten payloads after privacy or visible-surface policy changes."""
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'task_notifications_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            """Replace only the owned fixture helper to expose privacy or timeout failures."""
            (fixture / 'commands.jsonl').write_text('')
            (fixture / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "plugin/controller" as Controllers
ShellRoot {
 property int scenario: 0
 property int ticks: 0
 Controllers.TaskNotificationController { id: notices }
 Timer { interval: 30; running: true; repeat: true; onTriggered: {
  if (++ticks > 100) { console.error("NATIVE_FAIL policy revalidation deadline"); Qt.quit(); return }
  if (notices.inFlight) return
  if (scenario === 3) {
   if (notices.message !== "") { console.error("NATIVE_FAIL intentional discard became failure"); Qt.quit(); return }
   console.log("NATIVE_PASS policy revalidation"); Qt.quit(); return
  }
  notices.enabled = true
  notices.includeDeviceName = true
  notices.notify({state:"request_accepted", peerName:"PRIVATE-NAME", peerId:"fixture"})
  notices.startNext()
  if (scenario === 0) { notices.includeDeviceName = false; notices.enabled = false }
  if (scenario === 1) { notices.includeDeviceName = false; notices.includeDeviceName = true }
  if (scenario === 2) { notices.panelOpened = true; notices.panelOpened = false }
  scenario++
 } }
}''')
            (plugin / 'scripts/task_notification.py').write_text('''import sys
from pathlib import Path
raw=sys.stdin.buffer.read()
if raw: (Path.home()/"UNEXPECTED_NOTICE").write_bytes(raw)
print('{"ok":true}')
''')

        def inspect(fixture, home, output, calls):
            """Reject any leaked payload or provider call after an intentional policy discard."""
            self.assertIn('NATIVE_PASS policy revalidation', output)
            self.assertFalse((home / 'UNEXPECTED_NOTICE').exists())
            self.assertEqual(calls, [])

        runner.configure_fixture = configure
        runner.assert_fixture = inspect
        runner.test_actual_service_bar_panel_and_controls()

    def test_private_payload_limits_opt_in_and_markup_controls(self):
        """Reject malformed notices and neutralize private names before native rendering."""
        request = {'summary': 'File requests accepted', 'body': 'Delivery is unknown.',
                   'includeDeviceName': False, 'deviceName': ''}
        encode = lambda value: io.BytesIO(json.dumps(value, ensure_ascii=True).encode())
        self.assertEqual(notice.read_request(encode(request)), request)
        for invalid in (None, {}, {**request, 'extra': True}, {**request, 'includeDeviceName': 'true'},
                        {**request, 'deviceName': 'PRIVATE'}, {**request, 'body': 'x'*1025},
                        {**request, 'summary': '\ud800'}, {**request, 'body': 'a\0b'},
                        {**request, 'includeDeviceName': True, 'deviceName': 'x'*257}):
            with self.assertRaises((ValueError, UnicodeError)):
                notice.read_request(encode(invalid))
        for data in (b'x'*8193, b'\xff', b'{"body":"a","body":"b"}'):
            with self.assertRaises((ValueError, UnicodeError)):
                notice.read_request(io.BytesIO(data))
        name = notice.plain_name('\u202e<img src="https://invalid.test/x"> &lt;b&gt;\x01\nphone\u2069')
        self.assertNotIn('<', name)
        self.assertNotIn('>', name)
        self.assertNotIn('&', name)
        self.assertNotIn('https:', name)
        self.assertNotIn('\u202e', name)
        self.assertNotIn('\x01', name)
        self.assertLessEqual(len(notice.plain_name('x'*1000)), 128)

    @unittest.skipUnless(shutil.which('node'), 'Node absent')
    def test_opted_in_names_keep_complete_unicode_at_the_length_limit(self):
        """Keep complete Unicode names through the production queue and strict helper."""
        source = (ROOT/'controller/TaskNotificationController.qml').read_text()
        function = block(source, '    function notify(')
        names = ['a'*127 + '\U0001f4f1', '\U0001f4f1'*129, 'a'*129]
        script = """const vm=require('node:vm');
const input=JSON.parse(require('node:fs').readFileSync(0,'utf8'));
const context={suppressed:false,includeDeviceName:true,pending:[],
 strings:{t:key=>key},Qt:{callLater:()=>{}},root:{}};
vm.createContext(context);vm.runInContext(input.function,context);
for(const name of input.names) context.notify({state:'request_accepted',peerName:name,peerId:'fixture'});
process.stdout.write(JSON.stringify(context.pending));
"""
        result = subprocess.run(['node', '-e', script], input=json.dumps({'function': function, 'names': names}),
                                text=True, capture_output=True, timeout=3)
        self.assertEqual(result.returncode, 0, result.stderr)
        payloads = json.loads(result.stdout)
        self.assertEqual(len(payloads), len(names))
        for payload, name in zip(payloads, names):
            with self.subTest(name=name):
                validated = notice.read_request(io.BytesIO(json.dumps(payload).encode()))
                self.assertEqual(validated['deviceName'], name[:128])

    @unittest.skipUnless(shutil.which('node'), 'Node absent')
    def test_finish_emits_once_after_final_state_and_preserves_evidence(self):
        """Publish one final snapshot only after busy state and transient queues settle."""
        source = (ROOT/'controller/FileTransferController.qml').read_text()
        function = block(source, '    function finishOperation(')
        script = '''const vm=require('node:vm'),assert=require('node:assert/strict');
const input=JSON.parse(require('node:fs').readFileSync(0,'utf8'));
for(const state of ['request_accepted','submission_failed','submission_unknown','cancelled_before_submit','cancellation_unconfirmed']){
 const events=[];const c={operationBusy:true,fileBusy:true,submissionQueue:['private-path'],
  activeOperation:{id:'fixture',state,accepted:1,count:2,delivery:'unknown',cancellable:true},
  updateOperation(op){c.activeOperation=op},operationFinished(op){
    assert.equal(c.operationBusy,false);assert.equal(c.fileBusy,false);assert.equal(c.submissionQueue.length,0);
    events.push(op);
  }};vm.createContext(c);vm.runInContext(input,c);c.finishOperation();c.finishOperation();
 assert.equal(events.length,1);assert.equal(events[0].state,state);assert.equal(events[0].delivery,'unknown');
 assert.equal(events[0].accepted,1);assert.equal(events[0].cancellable,false);assert.notEqual(events[0],c.activeOperation);
}
'''
        result = subprocess.run(['node', '-e', script], input=json.dumps(function), text=True, capture_output=True, timeout=3)
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(importlib.util.find_spec('gi') and shutil.which('dbus-run-session'), 'Private Gio bus absent')
    def test_native_bus_metadata_privacy_and_fixed_failure_without_autostart(self):
        """Use private buses to verify metadata, bounded failures and no service autostart."""
        for mode in ('generic', 'detail', 'failure', 'timeout', 'unavailable'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix='plus-notice-bus-') as temporary:
                root = Path(temporary)
                (root/'runtime').mkdir(mode=0o700)
                services = root/'data/dbus-1/services'; services.mkdir(parents=True)
                fixture = ROOT/'tests/fake_task_notification.py'
                (services/'org.freedesktop.Notifications.service').write_text(
                    '[D-BUS Service]\nName=org.freedesktop.Notifications\nExec='+sys.executable+' '+str(fixture)+' activation\n')
                env = {'PATH': '/usr/bin', 'HOME': temporary, 'LANG': 'C.UTF-8',
                       'XDG_RUNTIME_DIR': str(root/'runtime'), 'XDG_DATA_HOME': str(root/'data'),
                       'XDG_DATA_DIRS': str(root/'empty'), 'PYTHONDONTWRITEBYTECODE': '1'}
                result = subprocess.run(['dbus-run-session', '--', sys.executable, str(fixture), mode],
                                        env=env, capture_output=True, text=True, timeout=8)
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                self.assertEqual(json.loads(result.stdout), {'passed': True, 'mode': mode})
                self.assertEqual(result.stderr, '')
                self.assertFalse((root/'UNEXPECTED_ACTIVATION').exists())

    def test_native_queue_suppression_visibility_and_coarse_failures(self):
        """Bound waiting notices and discard replay while any Plus surface is visible."""
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'task_notifications_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            # Controlled helper keeps the real QML process/queue/deadline boundary.
            """Replace only the owned fixture helper to expose privacy or timeout failures."""
            (plugin/'scripts/task_notification.py').write_text('''import json,sys,time
from pathlib import Path
value=json.load(sys.stdin)
with (Path.home()/'notices.jsonl').open('a') as out: out.write(json.dumps(value)+'\\n')
title=value['summary']
if title == 'Pending files cancelled': time.sleep(7)
if title == 'File submission failed': print('x'*2049,flush=True);time.sleep(1)
time.sleep(.15)
print(json.dumps({'ok':title != 'File submission unknown'}))
raise SystemExit(1 if title == 'File submission unknown' else 0)
''')

        def check(fixture, home, output, calls):
            """Verify generic notice outcomes without private names or shell dispatch."""
            self.assertIn('NATIVE_PASS task notifications', output)
            records = [json.loads(line) for line in (home/'notices.jsonl').read_text().splitlines()]
            self.assertEqual(len(records), 7)
            self.assertTrue(all(not value['includeDeviceName'] and value['deviceName'] == '' for value in records))
            self.assertEqual(records[0]['summary'], 'File requests accepted')
            self.assertFalse(any(row['tool'] == 'omarchy-shell' for row in calls), calls)

        runner.configure_fixture = configure
        runner.assert_fixture = check
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
