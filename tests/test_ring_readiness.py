"""Exercise the actual ring entry point with fake devices/actions only."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RingReadiness(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node parser fixture unavailable')
    def test_loaded_state_guard_and_honest_ring_request(self):
        source = (ROOT / 'KdeConnectController.qml').read_text()
        function = source[source.index('    function ringDevice('):source.index('    function sendClipboard(')]
        code = r'''const assert=require('node:assert/strict'), vm=require('node:vm');
const fn=JSON.parse(require('node:fs').readFileSync(0,'utf8')).function;
function fixture(loadedKnown, loaded, supported=true) {
 const calls=[];
 const device={id:'fixture-phone',capabilities:{ring:supported},loadedKnown,loadedPluginIds:loaded};
 const api=vm.createContext({deviceById:id=>id===device.id?device:null,startAction:(...args)=>{calls.push(args);return true},actionState:'idle',actionError:'',actionMessage:''});
 vm.runInContext(fn,api);
 return {api,device,calls};
}
let f=fixture(true,[]);
assert.equal(f.api.ringDevice('fixture-phone'),false,'known unloaded ring must not dispatch');
assert.equal(f.calls.length,0);
assert.equal(f.api.actionState,'blocked');
assert.match(f.api.actionError,/not active/i);
assert.match(f.api.actionError,/KDE Connect/i);
assert.equal(f.device.capabilities.ring,true,'supported capability stays visible');
f=fixture(true,['kdeconnect_findmyphone']);
assert.equal(f.api.ringDevice('fixture-phone'),true);
assert.equal(f.calls[0][0],'fixture-phone');
assert.equal(JSON.stringify(f.calls[0][1]),JSON.stringify(['kdeconnect-cli','-d','fixture-phone','--ring']));
assert.match(f.calls[0][2],/request/i,'CLI acceptance must not claim audible ringing');
f=fixture(false,[]);
assert.equal(f.api.ringDevice('fixture-phone'),true,'older snapshots retain native fallback');
assert.equal(f.calls.length,1);
f=fixture(true,[],false);
assert.equal(f.api.ringDevice('fixture-phone'),false);
assert.equal(f.calls.length,0);
assert.match(f.api.actionError,/not supported/i);
'''
        result = subprocess.run([shutil.which('node'), '-e', code], input=json.dumps({'function': function}), text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
