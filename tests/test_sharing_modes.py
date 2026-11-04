"""Exercise real chooser policy, generation and cancellation with owned doubles."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui

ROOT = Path(__file__).resolve().parents[1]


def block(source, marker):
    """Extract one production JavaScript block for execution in an isolated context."""
    start = source.index(marker)
    brace = source.index('{', start)
    depth, end = 1, brace + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


@unittest.skipUnless(shutil.which('node'), 'Node runtime absent')
class SharingPolicy(unittest.TestCase):
    def node(self, assertions):
        """Run real policy and controller functions with observable process doubles."""
        source = (ROOT / 'controller/FileTransferController.qml').read_text()
        names = ('chooseFiles', 'applySelection', 'selectionErrorText', 'cancelDraft',
                 'submitSelection', 'submitNextFile', 'updateOperation', 'finishOperation',
                 'cancelRemaining', 'cancelOperation', 'stageDroppedFiles')
        functions = '\n'.join(block(source, '    function ' + name + '(') for name in names)
        panel = (ROOT / 'Panel.qml').read_text()
        options = block(panel, '    readonly property var fileChooserOptions:')
        options = 'function chooserOptions() ' + options[options.index('{'):]
        panel_functions = options + '\n' + '\n'.join(block(panel, '    function ' + name + '(')
                                                    for name in ('getSetting', 'chooseFiles'))
        script = r'''
const vm=require('node:vm'),assert=require('node:assert/strict');
const input=JSON.parse(require('node:fs').readFileSync(0,'utf8'));
const model=vm.runInNewContext(input.model.replace(/^\.pragma library\s*/, '')+';({create,record,remember,status})');
function fresh(){
 const later=[],calls=[];
 const process=()=>({running:false,signals:[],signal(n){this.signals.push(n)}});
 const ctx={operationBusy:false,fileBusy:false,selection:[],selectionBytes:0,selectionState:'idle',selectionError:'',draftTarget:null,
  selectionGeneration:0,chooserSubmits:false,operationSequence:0,fileTransferGeneration:0,operations:[],activeOperation:null,
  submissionQueue:[],submissionIndex:0,cancellationRequested:false,fileTransferMessage:'',fileTransferError:'',
  fileTransferProcess:process(),filePickerProcess:process(),fileInspectProcess:process(),
  selectionCancellationTimer:{restart(){},stop(){}},cancellationTimer:{restart(){this.started=true}},TransferModel:model,Qt:{callLater(fn){later.push(fn)}},
  devices:[{id:'A',name:'Original phone',paired:true,reachable:true,capabilities:{file:true}},
           {id:'B',name:'Other phone',paired:true,reachable:true,capabilities:{file:true}}]};
 ctx.deviceById=id=>ctx.devices.find(d=>d.id===id);ctx.canAct=id=>{const d=ctx.deviceById(id);return !!d&&d.paired&&d.reachable};
 ctx.scriptPath=p=>'/fixture/'+p;ctx.getPickerScriptPath=()=>'/fixture/scripts/pick_file.sh';
 ctx.root=ctx;ctx.controller=ctx;vm.createContext(ctx);vm.runInContext(input.functions,ctx);
 let running=false;Object.defineProperty(ctx.fileTransferProcess,'running',{get(){return running},set(v){running=v;if(v)calls.push(JSON.parse(this.payload))}});
 return {ctx,later,calls,flush(){while(later.length)later.shift()()},selected(){ctx.filePickerProcess.running=false;ctx.applySelection(JSON.stringify({state:'selected',files:[{path:'/fixture/example.txt',name:'example.txt',size:3}]}),0,ctx.selectionGeneration)}};
}
function panel(settings,service,device){
 const ctx={settings,service,device};ctx.root=ctx;vm.createContext(ctx);vm.runInContext(input.panel,ctx);
 Object.defineProperty(ctx,'fileChooserOptions',{get(){return ctx.chooserOptions()}});return ctx;
}
const immediate={useDesktopFileChooser:false,reviewFilesBeforeSend:false};
const review={useDesktopFileChooser:true,reviewFilesBeforeSend:true};
'''
        result = subprocess.run(['node', '-e', script + assertions],
                                input=json.dumps({'functions': functions, 'panel': panel_functions,
                                                  'model': (ROOT / 'TransferModel.js').read_text()}),
                                text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_panel_defaults_normalizes_malformed_options_and_forwards_target(self):
        """Distinguish authorized defaults from malformed preferences before forwarding selection."""
        self.node(r'''
for(const settings of [{}]){
 const p=panel(settings,{},null);assert.deepEqual(JSON.parse(JSON.stringify(p.fileChooserOptions)),immediate);
}
for(const settings of [{useDesktopFileChooser:'false'},{reviewFilesBeforeSend:0},{useDesktopFileChooser:[],reviewFilesBeforeSend:false},
 {reviewFilesBeforeSend:null},{useDesktopFileChooser:null},{reviewFilesBeforeSend:undefined},null,undefined,[], 'false']){
 const p=panel(settings,{},null);assert.deepEqual(JSON.parse(JSON.stringify(p.fileChooserOptions)),review);
}
const seen=[];const p=panel({}, {chooseFiles(id,opts){seen.push({id,opts});return true}}, {id:'A'});
assert.equal(p.chooseFiles(),true);assert.equal(seen[0].id,'A');assert.equal(seen[0].opts.useDesktopFileChooser,false);
p.device=null;assert.equal(p.chooseFiles(),false);assert.equal(seen.length,1);
''')

    def test_immediate_freezes_target_and_policy_review_waits_for_explicit_send(self):
        """Preserve captured recipient and policy while review waits for explicit Send."""
        self.node(r'''
const f=fresh(),c=f.ctx,opts={...immediate};
assert.equal(c.chooseFiles('A',opts),true);assert.equal(c.filePickerProcess.command[2],'recent');
assert.equal(JSON.parse(c.filePickerProcess.payload).recipient,'Original phone');
assert.ok(Object.isFrozen(c.draftTarget));opts.reviewFilesBeforeSend=true;opts.useDesktopFileChooser=true;
c.selectedDeviceId='B';c.devices[0].name='Renamed later';f.selected();
assert.equal(f.calls.length,0,'inspection itself does not start provider');f.flush();
assert.equal(f.calls.length,1);assert.equal(f.calls[0].peerId,'A');assert.equal(c.activeOperation.peerName,'Original phone');
for(const options of [review,undefined,{}, {useDesktopFileChooser:false,reviewFilesBeforeSend:'false'}]){
 const g=fresh(),d=g.ctx;assert.equal(d.chooseFiles('A',options),true);
 assert.equal(d.filePickerProcess.command[0],'bash');g.selected();g.flush();
 assert.equal(g.calls.length,0);assert.equal(d.selectionState,'draft');
 assert.equal(d.submitSelection(),true);g.flush();assert.equal(g.calls.length,1);
}
// Even immediate mode must recheck its frozen recipient before any provider call.
const h=fresh();h.ctx.chooseFiles('A',immediate);h.selected();h.ctx.devices[0].reachable=false;h.flush();
assert.equal(h.calls.length,0);assert.equal(h.ctx.selectionState,'draft');
''')

    def test_stale_cancelled_drop_and_queued_results_never_start_provider(self):
        """Keep stale, cancelled, dropped and stopped queued selections from implicit submission."""
        self.node(r'''
const cancelled=fresh();cancelled.ctx.chooseFiles('A',immediate);
const old=cancelled.ctx.selectionGeneration;cancelled.ctx.cancelDraft();
assert.deepEqual(cancelled.ctx.filePickerProcess.signals,[15]);cancelled.selected();cancelled.flush();
assert.equal(cancelled.calls.length,0);assert.equal(cancelled.ctx.draftTarget,null);
const stale=fresh();stale.ctx.chooseFiles('A',immediate);const gen=stale.ctx.selectionGeneration;
stale.ctx.cancelDraft();stale.ctx.filePickerProcess.running=false;stale.ctx.chooseFiles('B',review);
stale.ctx.applySelection(JSON.stringify({state:'selected',files:[{path:'/fixture/x',size:1}]}),0,gen);stale.flush();
assert.equal(stale.calls.length,0);assert.equal(stale.ctx.draftTarget.peerId,'B');assert.equal(stale.ctx.selectionState,'choosing');
const response=fresh();response.ctx.chooseFiles('A',immediate);response.ctx.filePickerProcess.running=false;
response.ctx.applySelection('{"state":"cancelled","files":[]}',0,response.ctx.selectionGeneration);response.flush();assert.equal(response.calls.length,0);
const pending=fresh();pending.ctx.chooseFiles('A',immediate);pending.selected();pending.ctx.cancelDraft();pending.flush();assert.equal(pending.calls.length,0);
const queued=fresh();queued.ctx.chooseFiles('A',review);queued.selected();queued.ctx.submitSelection();
assert.equal(queued.ctx.fileTransferState,'queued');assert.equal(queued.ctx.cancelOperation(),true);queued.flush();
assert.equal(queued.calls.length,0);assert.equal(queued.ctx.operationBusy,false);assert.equal(queued.ctx.activeOperation.cancelled,1);
const drop=fresh();assert.equal(drop.ctx.stageDroppedFiles('A',['file:///fixture/example.txt']),true);
assert.equal(drop.ctx.chooserSubmits,false);drop.ctx.fileInspectProcess.running=false;drop.selected();drop.flush();
assert.equal(drop.calls.length,0);assert.equal(drop.ctx.selectionState,'draft');
const active=fresh();active.ctx.chooseFiles('A',immediate);active.selected();active.flush();
assert.equal(active.ctx.cancelOperation(),true);assert.equal(active.ctx.cancelOperation(),false);
assert.deepEqual(active.ctx.fileTransferProcess.signals,[15]);assert.equal(active.calls.length,1);
''')


class SharingNative(unittest.TestCase):
    def test_native_default_menu_immediate_review_and_global_cancel(self):
        """Exercise actual chooser modes and accessible cancellation on a private native bus."""
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'sharing_modes_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            """Provide a temporary recent file and logged native menu double."""
            downloads = home / 'Downloads'
            downloads.mkdir()
            (downloads / 'example.txt').write_bytes(b'owned menu fixture')
            menu = fake_bin / 'omarchy-menu-select'
            menu.write_text('''#!/usr/bin/python3
import json,os,sys,time
with open(os.environ['NATIVE_COMMAND_LOG'],'a') as out:
 out.write(json.dumps({'tool':'omarchy-menu-select','args':sys.argv[1:]})+'\\n')
time.sleep(.15)
print(sys.argv[2])
''')
            menu.chmod(0o700)

        def checked(fixture, home, output, calls):
            """Check exact synthetic menu, portal and recipient-specific submission receipts."""
            self.assertIn('SHARING_MODES_PASS', output)
            menu = [row for row in calls if row['tool'] == 'omarchy-menu-select']
            self.assertEqual(len(menu), 1, calls)
            self.assertIn('Original phone', menu[0]['args'][0])
            submissions = [row for row in calls if row['tool'] == 'kdeconnect-share']
            self.assertEqual(len(submissions), 4, calls)
            self.assertTrue(all(row['args'][0] == 'A' for row in submissions), submissions)
            self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()),
                             [{'multiple': True, 'directory': False}] * 2)
            self.assertFalse(any(row['tool']=='kdeconnect-cli' for row in calls), calls)
            self.assertEqual((home/'Downloads/example.txt').read_bytes(), b'owned menu fixture')

        runner.configure_fixture = configure
        runner.assert_fixture = checked
        runner.test_actual_service_bar_panel_and_controls()

    def test_native_stubborn_picker_cancel_escalates_then_next_choice_works(self):
        """Verify forced picker exit preserves cancellation feedback and permits a fresh choice."""
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'picker_cancel_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            """Create a picker that first ignores SIGTERM, then returns an inspected review."""
            (plugin/'scripts/pick_file.sh').write_text(
                '#!/bin/bash\nexec python3 "$(dirname -- "$0")/stubborn_picker.py"\n')
            (plugin/'scripts/stubborn_picker.py').write_text('''import json,signal,time
from pathlib import Path
from portal_files import inspect_uris
home=Path.home()
count_file=home/'picker-count'
count=int(count_file.read_text())+1 if count_file.exists() else 1
count_file.write_text(str(count))
if count==1:
 signal.signal(signal.SIGTERM,signal.SIG_IGN)
 (home/'picker-ready').write_text('ready')
 time.sleep(30)
else:
 print(json.dumps({'state':'selected','files':inspect_uris([(home.parent/'one').as_uri()])}))
''')

        def checked(fixture, home, output, calls):
            """Confirm picker recovery started no native transfer or portal request."""
            self.assertIn('PICKER_CANCEL_PASS', output)
            self.assertEqual((home/'picker-count').read_text(), '2')
            self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()), [])
            self.assertFalse(any(row['tool'] in ('kdeconnect-share','kdeconnect-cli') for row in calls), calls)

        runner.configure_fixture = configure
        runner.assert_fixture = checked
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
