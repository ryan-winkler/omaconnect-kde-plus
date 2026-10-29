"""File-drop review boundaries. No real transfer or native file-manager action."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui

ROOT = Path(__file__).resolve().parents[1]


class DropFiles(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node runtime absent')
    def test_actual_controller_stages_inspected_files_without_sending_or_retargeting(self):
        source = (ROOT / 'controller' / 'FileTransferController.qml').read_text()
        def extract(name):
            start = source.index('    function ' + name + '(')
            brace = source.index('{', start)
            depth, end = 1, brace + 1
            while depth:
                depth += (source[end] == '{') - (source[end] == '}')
                end += 1
            return source[start:end]
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            one, two = base/'photo one.unknown', base/'empty'
            one.write_bytes(b'abc'); two.touch()
            uris = [one.as_uri(), two.as_uri()]
            inspected = subprocess.run(['/usr/bin/python3', str(ROOT/'scripts/portal_files.py'), 'inspect'], input=json.dumps(uris), text=True, capture_output=True, check=True)
            result = json.loads(inspected.stdout)
            self.assertEqual([item['size'] for item in result['files']], [3, 0])
            script = r'''const vm=require('node:vm'), assert=require('node:assert/strict');
const input=JSON.parse(require('node:fs').readFileSync(0,'utf8'));
const ctx={operationBusy:false, fileTransferProcess:{running:false},filePickerProcess:{running:false,signal(){}},fileInspectProcess:{running:false,signal(){}},
 selectionState:'idle',selection:[],selectionBytes:0,selectionError:'',selectionGeneration:0,draftTarget:null,
 devices:[{id:'A',name:'Reviewed phone',paired:true,reachable:true,capabilities:{file:true}},{id:'B',name:'Another phone',paired:true,reachable:true,capabilities:{file:true}}]};
ctx.deviceById=id=>ctx.devices.find(d=>d.id===id);ctx.canAct=id=>!!ctx.deviceById(id);ctx.controller=ctx;vm.createContext(ctx);vm.runInContext(input.functions,ctx);
assert.equal(ctx.stageDroppedFiles('A',input.uris),true);
assert.equal(JSON.parse(ctx.fileInspectProcess.payload).join(','),input.uris.join(','));
assert.equal(ctx.draftTarget.peerId,'A');assert.ok(Object.isFrozen(ctx.draftTarget));
const generation=ctx.selectionGeneration;ctx.selectedDeviceId='B';ctx.fileInspectProcess.running=false;
ctx.applySelection(JSON.stringify(input.result),0,generation);
assert.equal(ctx.selectionState,'draft');assert.equal(ctx.draftTarget.peerId,'A');assert.equal(ctx.selectionBytes,3);
assert.equal(ctx.fileTransferProcess.running,false,'dropping never sends');
const target=ctx.draftTarget,files=ctx.selection;
assert.equal(ctx.stageDroppedFiles('B',input.uris),false);assert.equal(ctx.draftTarget,target);assert.equal(ctx.selection,files);assert.match(ctx.selectionError,/clear/);
ctx.cancelDraft();ctx.operationBusy=true;assert.equal(ctx.stageDroppedFiles('A',input.uris),false);assert.equal(ctx.draftTarget,null);ctx.operationBusy=false;
for(const bad of [[],new Array(101).fill(input.uris[0]),[null],['https://example.invalid/x'],['file://otherhost/tmp/x'],['file:///tmp/'+ 'x'.repeat(16385)],new Array(20).fill('file:///'+ 'x'.repeat(10000))]) {
 assert.equal(ctx.stageDroppedFiles('A',bad),false);assert.equal(ctx.fileInspectProcess.running,false);assert.equal(ctx.draftTarget,null);
}
assert.equal(ctx.stageDroppedFiles('A',input.uris),true);
ctx.fileInspectProcess.running=false;ctx.applySelection('{"state":"failed","error":"source-path-rejected"}',1,ctx.selectionGeneration);
assert.equal(ctx.selectionState,'idle');assert.equal(ctx.stageDroppedFiles('B',input.uris),true,'a failed inspection can be retried');
const newTarget=ctx.draftTarget;ctx.applySelection(JSON.stringify(input.result),0,generation);assert.equal(ctx.draftTarget,newTarget);assert.equal(ctx.selection.length,0,'stale inspection is ignored');
'''
            functions = '\n'.join(extract(n) for n in ('stageDroppedFiles', 'applySelection', 'selectionErrorText', 'cancelDraft'))
            check = subprocess.run(['node', '-e', script], input=json.dumps({'functions':functions,'uris':uris,'result':result}), text=True, capture_output=True, timeout=5)
            self.assertEqual(check.returncode, 0, check.stderr)

    def test_actual_inspector_rejects_remote_urls_folders_and_symlinks(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary); file = base/'source';file.write_text('test');link=base/'link';link.symlink_to(file)
            for uri in [base.as_uri(),link.as_uri(),'https://example.invalid/file','file://remote/tmp/x','file:///tmp/%00bad']:
                check = subprocess.run(['/usr/bin/python3',str(ROOT/'scripts/portal_files.py'),'inspect'],input=json.dumps([uri]),text=True,capture_output=True,timeout=5)
                self.assertEqual(json.loads(check.stdout)['state'],'failed',uri)
                self.assertNotIn(str(file),check.stdout+check.stderr)

    def configure_fixture(self, fixture, plugin, home, fake_bin):
        (fixture/'commands.jsonl').write_text('')

    def assert_fixture(self, fixture, home, output, calls):
        self.assertIn('DROP_PASS', output, output)
        self.assertTrue(all(row["tool"] in ("fc-match", "hyprctl") for row in calls), calls)
        self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()), [])

    def test_native_drop_zone_accepts_only_copy_for_review_and_respects_busy_state(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='drop_files_ui.qml';runner.force_offscreen=True
        runner.configure_fixture=self.configure_fixture;runner.assert_fixture=self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__': unittest.main()
