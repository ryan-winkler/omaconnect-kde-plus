"""Exercise real chooser policy, generation and cancellation with owned doubles."""
import json
from pathlib import Path
import shutil
import struct
import subprocess
import unittest
import zlib

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
        names = ('chooseFiles', 'launchChooser', 'validPreviewPaths', 'backToFiles', 'confirmPreview', 'applySelection', 'selectionErrorText', 'cancelDraft',
                 'submitSelection', 'submitNextFile', 'updateOperation', 'finishOperation',
                 'cancelRemaining', 'cancelOperation', 'cancelFileTransfer', 'stageDroppedFiles')
        functions = '\n'.join(block(source, '    function ' + name + '(') for name in names)
        panel = (ROOT / 'Panel.qml').read_text()
        options = block(panel, '    readonly property var fileChooserOptions:')
        options = 'function chooserOptions() ' + options[options.index('{'):]
        panel_functions = options + '\n' + '\n'.join(block(panel, '    function ' + name + '(')
                                                    for name in ('getSetting', 'chooseFiles', 'backToFiles', 'releasePreview'))
        script = r'''
const vm=require('node:vm'),assert=require('node:assert/strict');
const input=JSON.parse(require('node:fs').readFileSync(0,'utf8'));
const Locale={Strings:require(input.catalogFixture)};
const model=vm.runInNewContext(input.model.replace(/^\.pragma library\s*/, '')+';({create,record,remember,status})');
function fresh(){
 const later=[],calls=[];
 const process=()=>({running:false,signals:[],signal(n){this.signals.push(n)}});
 const ctx={Locale,operationBusy:false,fileBusy:false,selection:[],selectionBytes:0,selectionState:'idle',selectionError:'',draftTarget:null,
  selectionGeneration:0,chooserSubmits:false,previewCandidates:[],operationSequence:0,fileTransferGeneration:0,operations:[],activeOperation:null,
  submissionQueue:[],submissionIndex:0,cancellationRequested:false,fileTransferMessage:'',fileTransferError:'',
  fileTransferProcess:process(),filePickerProcess:process(),fileInspectProcess:process(),
  selectionCancellationTimer:{restart(){},stop(){}},cancellationTimer:{restart(){this.started=true}},operationFinished(){},TransferModel:model,Qt:{callLater(fn){later.push(fn)}},
  devices:[{id:'A',name:'Original phone',paired:true,reachable:true,capabilities:{file:true}},
           {id:'B',name:'Other phone',paired:true,reachable:true,capabilities:{file:true}}]};
 ctx.deviceById=id=>ctx.devices.find(d=>d.id===id);ctx.canAct=id=>{const d=ctx.deviceById(id);return !!d&&d.paired&&d.reachable};
 ctx.scriptPath=p=>'/fixture/'+p;ctx.getPickerScriptPath=()=>'/fixture/scripts/pick_file.sh';
 ctx.root=ctx;ctx.controller=ctx;vm.createContext(ctx);vm.runInContext(input.functions,ctx);
 let running=false;Object.defineProperty(ctx.fileTransferProcess,'running',{get(){return running},set(v){running=v;if(v)calls.push(JSON.parse(this.payload))}});
 return {ctx,later,calls,flush(){while(later.length)later.shift()()},selected(){ctx.filePickerProcess.running=false;ctx.applySelection(JSON.stringify({state:'selected',files:[{path:'/fixture/example.txt',name:'example.txt',size:3}]}),0,ctx.selectionGeneration)}};
}
function panel(settings,service,device){
 const ctx={settings,service,device,previewGeneration:-1};ctx.root=ctx;vm.createContext(ctx);vm.runInContext(input.panel,ctx);
 Object.defineProperty(ctx,'fileChooserOptions',{get(){return ctx.chooserOptions()}});return ctx;
}
const immediate={useDesktopFileChooser:false,reviewFilesBeforeSend:false};
const review={useDesktopFileChooser:true,reviewFilesBeforeSend:true};
'''
        result = subprocess.run(['node', '-e', script + assertions],
                                input=json.dumps({'functions': functions, 'panel': panel_functions,
                                                  'model': (ROOT / 'TransferModel.js').read_text(),
                                                  'catalogFixture': str(ROOT / 'tests/english_catalog.cjs')}),
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
assert.deepEqual(JSON.parse(c.filePickerProcess.payload), {
 recipient:'Original phone', title:'Select file to send to Original phone', previewLabel:'Image previews…'
});
assert.ok(Object.isFrozen(c.draftTarget));opts.reviewFilesBeforeSend=true;opts.useDesktopFileChooser=true;
c.selectedDeviceId='B';c.devices[0].name='Renamed later';f.selected();
assert.equal(f.calls.length,0,'inspection itself does not start provider');f.flush();
assert.equal(f.calls.length,1);assert.equal(f.calls[0].peerId,'A');assert.equal(c.activeOperation.peerName,'Original phone');
for(const options of [review,undefined,{}, {useDesktopFileChooser:false,reviewFilesBeforeSend:'false'}]){
 const g=fresh(),d=g.ctx;assert.equal(d.chooseFiles('A',options),true);
 assert.equal(d.filePickerProcess.command[0],'bash');
 assert.equal(d.filePickerProcess.command[2],'Select files to send');g.selected();g.flush();
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

    def test_preview_handoff_bounds_and_exact_candidate_before_inspection(self):
        """Reject unsafe handoffs before display and unoffered confirmations before inspection."""
        self.node(r'''
const f=fresh(),c=f.ctx;const paths=['/fixture/folder/photo #1 ☃.PNG','/fixture/other/photo #1 ☃.PNG'];
assert.equal(c.chooseFiles('A',immediate),true);c.filePickerProcess.running=false;
c.applySelection(JSON.stringify({state:'preview',paths}),0,c.selectionGeneration);
assert.equal(c.selectionState,'preview');assert.deepEqual(JSON.parse(JSON.stringify(c.previewCandidates)),paths);
assert.equal(c.draftTarget.peerId,'A');assert.equal(c.chooserSubmits,true);assert.equal(f.calls.length,0);
assert.equal(c.confirmPreview('/fixture/unoffered.png'),false);assert.equal(c.fileInspectProcess.running,false);
assert.equal(c.chooseFiles('B',immediate),false);assert.equal(c.stageDroppedFiles('B',['file:///fixture/x.png']),false);
for(const invalid of [null,{},[],[null],new Array(201).fill('/fixture/x.png'),['relative.png'],['file:///fixture/x.png'],
 ['/fixture/x.svg'],['/fixture/../x.png'],['/fixture//x.png'],['/fixture/control\n.png'],['/fixture/\u202ex.png'],
 ['/fixture/\u200dx.png'],['/fixture/\ud800.png'],['/fixture/'+'☃'.repeat(1400)+'.png'],['/fixture/x.png','/fixture/x.png'],
 Array.from({length:20},(_,i)=>'/fixture/'+i+'x'.repeat(3000)+'.png')]) {
 assert.equal(c.validPreviewPaths(invalid),false,JSON.stringify(invalid).slice(0,100));
}
assert.equal(c.validPreviewPaths(['/fixture/emoji 😀.jpg']),true);
const g=fresh();g.ctx.chooseFiles('A',review);g.ctx.filePickerProcess.running=false;
g.ctx.applySelection(JSON.stringify({state:'preview',paths}),0,g.ctx.selectionGeneration);
assert.notEqual(g.ctx.selectionState,'preview');assert.equal(g.calls.length,0);
''')

    def test_preview_back_freezes_recipient_policy_and_invalidates_old_generation(self):
        """Return to the native list without adopting changed settings or another recipient."""
        self.node(r'''
for(const reviewFirst of [false,true]) {
 const f=fresh(),c=f.ctx,options={useDesktopFileChooser:false,reviewFilesBeforeSend:reviewFirst};
 c.chooseFiles('A',options);c.filePickerProcess.running=false;
 const generation=c.selectionGeneration;
 c.applySelection(JSON.stringify({state:'preview',paths:['/fixture/a.png']}),0,generation);
 options.reviewFilesBeforeSend=!reviewFirst;options.useDesktopFileChooser=true;
 c.selectedDeviceId='B';c.devices[0].name='Renamed later';
 assert.equal(c.backToFiles(),true);assert.equal(c.selectionGeneration,generation+1);
 assert.equal(c.filePickerProcess.command[2],'recent');assert.equal(c.draftTarget.peerId,'A');
 assert.equal(JSON.parse(c.filePickerProcess.payload).recipient,'Original phone');
 assert.equal(c.chooserSubmits,!reviewFirst);assert.equal(c.previewCandidates.length,0);
 c.applySelection(JSON.stringify({state:'preview',paths:['/fixture/stale.png']}),0,generation);
 assert.equal(c.selectionState,'choosing');assert.equal(c.previewCandidates.length,0);assert.equal(f.calls.length,0);
}
const f=fresh(),c=f.ctx;c.chooseFiles('A',immediate);c.filePickerProcess.running=false;
c.applySelection(JSON.stringify({state:'preview',paths:['/fixture/a.png']}),0,c.selectionGeneration);
c.devices[0].reachable=false;c.selectedDeviceId='B';assert.equal(c.backToFiles(),true);
assert.equal(c.draftTarget.peerId,'A');assert.equal(c.chooserSubmits,true);
assert.equal(JSON.parse(c.filePickerProcess.payload).recipient,'Original phone');
f.selected();f.flush();assert.equal(f.calls.length,0);assert.equal(c.selectionState,'draft');
assert.equal(c.draftTarget.peerId,'A');assert.match(c.selectionError,/no longer paired and reachable/);
''')

    def test_panel_generation_owner_is_single_and_destruction_cancels_only_its_preview(self):
        """Multiple panels keep one origin and release only their unfinished selection."""
        self.node(r'''
const f=fresh(),c=f.ctx,a=panel({},c,c.devices[0]),b=panel({},c,c.devices[0]);
assert.equal(a.chooseFiles(),true);assert.equal(a.previewGeneration,c.selectionGeneration);assert.equal(b.previewGeneration,-1);
c.filePickerProcess.running=false;c.applySelection(JSON.stringify({state:'preview',paths:['/fixture/a.png']}),0,c.selectionGeneration);
assert.equal(b.chooseFiles(),false);assert.equal(b.previewGeneration,-1);assert.equal(b.backToFiles(),false);
b.releasePreview();assert.equal(c.selectionState,'preview');
assert.equal(a.backToFiles(),true);assert.equal(a.previewGeneration,c.selectionGeneration);
c.filePickerProcess.running=false;c.applySelection(JSON.stringify({state:'preview',paths:['/fixture/a.png']}),0,c.selectionGeneration);
a.releasePreview();assert.equal(c.selectionState,'idle');assert.equal(c.draftTarget,null);
assert.equal(b.chooseFiles(),true);assert.equal(b.previewGeneration,c.selectionGeneration);
a.releasePreview();assert.equal(c.selectionState,'choosing');assert.equal(c.draftTarget.peerId,'A');
c.filePickerProcess.running=false;c.applySelection(JSON.stringify({state:'preview',paths:['/fixture/a.png']}),0,c.selectionGeneration);
assert.equal(c.confirmPreview('/fixture/a.png'),true);b.releasePreview();
assert.equal(c.selectionState,'choosing');assert.equal(c.fileInspectProcess.running,true);
c.fileInspectProcess.running=false;c.applySelection(JSON.stringify({state:'selected',files:[{path:'/fixture/a.png',size:3}]}),0,c.selectionGeneration);
f.flush();assert.equal(f.calls.length,1);b.releasePreview();assert.equal(c.operationBusy,true);
const g=fresh(),d=g.ctx,p=panel({reviewFilesBeforeSend:true},d,d.devices[0]);
p.chooseFiles();g.selected();p.releasePreview();assert.equal(d.selectionState,'draft');assert.equal(d.selection.length,1);
const none=panel({},null,null);none.releasePreview();assert.equal(none.backToFiles(),false);
''')

    def test_preview_explicit_confirmation_uses_inspector_then_captured_send_or_review(self):
        """Browsing cannot send; only an exact explicit confirmation enters inspected submission."""
        self.node(r'''
for(const reviewFirst of [false,true]) {
 const f=fresh(),c=f.ctx,path='/fixture/photo #1 ☃.png';
 c.chooseFiles('A',{useDesktopFileChooser:false,reviewFilesBeforeSend:reviewFirst});c.filePickerProcess.running=false;
 c.applySelection(JSON.stringify({state:'preview',paths:[path]}),0,c.selectionGeneration);
 f.flush();assert.equal(f.calls.length,0);assert.equal(c.selection.length,0);
 c.selectedDeviceId='B';assert.equal(c.confirmPreview(path),true);assert.equal(c.previewCandidates.length,0);
 assert.equal(c.confirmPreview(path),false);assert.equal(c.fileInspectProcess.running,true);
 const uri=JSON.parse(c.fileInspectProcess.payload)[0];assert.equal(decodeURIComponent(new URL(uri).pathname),path);
 assert.equal(f.calls.length,0);c.fileInspectProcess.running=false;
 c.applySelection(JSON.stringify({state:'selected',files:[{path,name:'photo #1 ☃.png',size:3}]}),0,c.selectionGeneration);
 f.flush();assert.equal(f.calls.length,reviewFirst?0:1);
 if(reviewFirst){assert.equal(c.selectionState,'draft');assert.equal(c.submitSelection(),true);f.flush()}
 assert.equal(f.calls.length,1);assert.equal(f.calls[0].peerId,'A');assert.equal(c.activeOperation.peerName,'Original phone');
}
''')

    def test_preview_cancel_stale_inspection_and_unreachable_original_never_submit(self):
        """Cancel removes preview state; changed peer availability blocks confirmation."""
        self.node(r'''
for(const confirm of [false,true]) {
 const f=fresh(),c=f.ctx,path='/fixture/a.png';c.chooseFiles('A',immediate);c.filePickerProcess.running=false;
 c.applySelection(JSON.stringify({state:'preview',paths:[path]}),0,c.selectionGeneration);
 if(confirm)assert.equal(c.confirmPreview(path),true);
 const generation=c.selectionGeneration;c.cancelDraft();c.fileInspectProcess.running=false;
 c.applySelection(JSON.stringify({state:'selected',files:[{path,size:3}]}),0,generation);f.flush();
 assert.equal(c.selectionState,'idle');assert.equal(c.previewCandidates.length,0);assert.equal(c.draftTarget,null);assert.equal(f.calls.length,0);
}
const f=fresh(),c=f.ctx;c.chooseFiles('A',immediate);c.filePickerProcess.running=false;
c.applySelection(JSON.stringify({state:'preview',paths:['/fixture/a.png']}),0,c.selectionGeneration);
c.devices[0].reachable=false;assert.equal(c.confirmPreview('/fixture/a.png'),false);
assert.equal(c.selectionState,'preview');assert.match(c.selectionError,/original recipient/);assert.equal(f.calls.length,0);
''')


class SharingNative(unittest.TestCase):
    def test_native_preview_has_one_origin_across_panels_and_releases_destroyed_owner(self):
        """Load two real Panels sharing one service and exercise scoped generation ownership."""
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'preview_owner_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            """Offer one owned raster through the logged native-menu double."""
            def chunk(kind, data):
                return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
            pictures = home / 'Pictures'
            pictures.mkdir()
            (pictures / 'owned.png').write_bytes(
                b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(b'\x00\x80\xc0\x70')) + chunk(b'IEND', b''))
            menu = fake_bin / 'omarchy-menu-select'
            menu.write_text('''#!/usr/bin/python3
import json,os,sys
with open(os.environ['NATIVE_COMMAND_LOG'],'a') as out:
 out.write(json.dumps({'tool':'omarchy-menu-select','args':sys.argv[1:]})+'\\n')
print('Image previews…')
''')
            menu.chmod(0o700)

        def checked(fixture, home, output, calls):
            """Ownership navigation and destruction must never start a native transfer."""
            self.assertIn('PREVIEW_OWNER_PASS', output)
            self.assertGreaterEqual(sum(row['tool'] == 'omarchy-menu-select' for row in calls), 4)
            self.assertFalse(any(row['tool'] in ('kdeconnect-share', 'kdeconnect-cli') for row in calls), calls)
            self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])

        runner.configure_fixture = configure
        runner.assert_fixture = checked
        runner.test_actual_service_bar_panel_and_controls()

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
print(sys.argv[2].split('\\t',1)[-1])
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
