const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const base = process.argv[2] || path.resolve(__dirname, '..');
const model = fs.readFileSync(path.join(base, 'BthControlModel.js'), 'utf8').replace(/^\.pragma library\s*/, '');
const M = {}; vm.createContext(M); vm.runInContext(model, M);
const good = {schema_version: 1, configured: true, profile_safe: true, control_valid: true, nm_control: true, pending: false, control_mode: 'auto', connection_state: 'inactive', error: null};
let count = 0;
function test(name, fn) { fn(); console.log('ok '+(++count)+' '+name); }
function parse(change={}) { return M.parse(JSON.stringify({...good, ...change})); }
test('inactive saved BTH remains a known Off connection in Automatic mode', () => {
 const s=parse(); assert.equal(s.known,true); assert.equal(M.stateLabel(s.connection_state),'Off'); assert.equal(M.modeLabel(s.control_mode),'Automatic');
});
test('malformed, oversized and non-object status are unavailable', () => {
 for(const value of ['', '{', '[]', 'null', 'x'.repeat(8193)]) assert.equal(M.parse(value).known,false);
});
test('schema enums booleans and error codes are strict', () => {
 for(const change of [{schema_version:2},{control_mode:'shell'},{connection_state:'connected'},{configured:1},{pending:'false'},{error:'<img src="remote">'}]) assert.equal(parse(change).known,false);
});
test('untrusted extra fields do not enter the display model', () => {
 const s=parse({password:'DO-NOT-RETAIN',profile_name:'<img src="remote">'}); assert.equal('password' in s,false); assert.equal('profile_name' in s,false);
});
test('only three fixed mode commands are accepted', () => {
 assert.equal(M.command('auto'),'auto');assert.equal(M.command('on'),'bth-on');assert.equal(M.command('off'),'bth-off');
 for(const value of ['sh','bth-off; whoami','--config','control-status','',null]) assert.equal(M.command(value),'');
});
test('guarded On and Auto do not activate unsafe or missing profiles', () => {
 for(const mode of ['on','auto']) for(const change of [{configured:false},{profile_safe:false},{nm_control:false}]) assert.equal(M.canRun(parse(change),mode,false),false);
 assert.equal(M.canRun(parse(), 'on',true),false);
});
test('Off remains available for exact identified profile after safety or intent drift', () => {
 assert.equal(M.canRun(parse({profile_safe:false,control_valid:false,error:'unsafe-profile'}),'off',false),true);
 assert.equal(M.canRun(parse({configured:false}),'off',false),false);assert.equal(M.canRun(parse({nm_control:false}),'off',false),false);
});
test('explicit Automatic or Off can replace invalid intent but On cannot', () => {
 const s=parse({control_valid:false,error:'invalid-control-state'});
 assert.equal(M.canRun(s,'auto',false),true);assert.equal(M.canRun(s,'off',false),true);assert.equal(M.canRun(s,'on',false),false);
});
test('activation errors cannot be hidden by inconsistent otherwise-safe booleans', () => {
 for(const error of ['not-configured','unsafe-profile','not-preauthorized']) {
  assert.equal(M.canRun(parse({error}), 'on', false),false);
  assert.equal(M.canRun(parse({error}), 'auto', false),false);
 }
});
test('invalid saved intent is Needs review with no normal Automatic selection', () => {
 const invalid=parse({control_mode:'auto',control_valid:false,error:'invalid-control-state'});
 assert.equal(M.selectedModeLabel(invalid),'Needs review');
 for(const mode of ['auto','on','off']) assert.equal(M.isSelected(invalid,mode),false);
 assert.equal(M.isSelected(parse(),'auto'),true);assert.equal(M.selectedModeLabel(parse()),'Automatic');
 assert.equal(M.selectedModeLabel(M.unknown()),'Unknown');
 assert.equal(M.canRun(invalid,'off',false),true);assert.equal(M.canRun(invalid,'auto',false),true);
});
test('queued mode never becomes an actual On result until interface active', () => {
 assert.equal(M.confirmed(parse({control_mode:'on',connection_state:'activating',pending:true}),'on'),false);
 assert.equal(M.confirmed(parse({control_mode:'on',connection_state:'inactive'}),'on'),false);
 assert.equal(M.confirmed(parse({control_mode:'on',connection_state:'active'}),'on'),true);
 assert.match(M.pendingText(parse(), 'on'),/Waiting for actual/);
});
test('Off and Automatic confirmations require settled NM readback', () => {
 assert.equal(M.confirmed(parse({control_mode:'off',connection_state:'deactivating',pending:true}),'off'),false);
 assert.equal(M.confirmed(parse({control_mode:'off'}),'off'),true);
 assert.equal(M.confirmed(parse({connection_state:'activating'}),'auto'),false);
 assert.equal(M.confirmed(parse(), 'auto'),true);
 assert.equal(M.confirmed(parse({control_mode:'on',connection_state:'active',profile_safe:false,error:'unsafe-profile'}),'on'),false);
 assert.equal(M.confirmed(parse({nm_control:false,error:'not-preauthorized'}),'auto'),false);
 assert.equal(M.confirmed(parse({control_mode:'off',profile_safe:false,error:'unsafe-profile'}),'off'),true);
});
test('last apply failure stays generic, has bounded age and clears on applied report', () => {
 const failed=parse({pending:true,last_report:{phase:'error',age_seconds:10,control_mode:'auto',reason:'<img src="remote">'}});
 assert.equal(failed.last_apply_failed,true);assert.equal(failed.last_report_age_seconds,10);
 assert.equal(M.pendingText(failed,'on'),'Last apply failed. Inspect status, or choose Off or Automatic.');
 assert.equal('reason' in failed,false);
 const applied=parse({last_report:{phase:'applied',age_seconds:0}});assert.equal(applied.last_apply_failed,false);
 assert.equal(M.pendingText(applied,''),'');
 assert.equal(parse({last_report:{phase:'<img>',age_seconds:Infinity}}).last_apply_failed,false);
 assert.equal(parse({last_report:{phase:'error',age_seconds:-1}}).last_report_age_seconds,null);
});
test('state labels make no handshake or service-health claim', () => {
 assert.equal(M.stateLabel('active'),'On (interface active)');assert.equal(M.stateLabel('inactive'),'Off');assert.equal(M.stateLabel('activating'),'Turning on');
 for(const mode of ['active','inactive','activating','deactivating']) assert.doesNotMatch(M.stateLabel(mode),/healthy|verified|connected/i);
});
const card=fs.readFileSync(path.join(base,'BthControlCard.qml'),'utf8');

test('fixed helper argv and bounded output keep shell and raw stderr out', () => {
 assert.ok(card.includes('"/.local/bin/remote-access-mode"'));
 assert.ok(card.includes('["/usr/bin/timeout", "4", root.helperPath, "control-status"]'));
 assert.ok(card.includes('["/usr/bin/timeout", "8", root.helperPath, Control.command(mode)]'));
 assert.equal((card.match(/text.length > Control.MAX_STATUS/g)||[]).length,2);
 assert.doesNotMatch(card,/"sh"|"bash"|"nmcli"|execDetached/);
});
test('optional card only polls while open and rejects relative helper paths', () => {
 assert.ok(card.includes('running: root.panelOpened'));
 assert.ok(card.includes('Optional BTH controller is not installed'));
 assert.ok(M.validHelperPath('/tmp/installed/remote-access-mode'));
 for (const value of ['remote-access-mode', '/tmp/../remote-access-mode', '/tmp/evil', '/tmp/remote-access-mode\n']) assert.equal(M.validHelperPath(value), false);
 assert.equal((card.match(/\bText \{/g)||[]).length,(card.match(/textFormat: Text.PlainText/g)||[]).length);
 assert.ok(card.includes('Accessible.name')); assert.ok(card.includes('focusable: true'));
});
console.log(count+' BTH control checks passed');

const discovery = {}; vm.createContext(discovery);
vm.runInContext(fs.readFileSync(path.join(base, 'DiscoveryModel.js'), 'utf8').replace(/^\.pragma library\s*/, ''), discovery);
test('rediscovery needs both open-panel and explicit opt-in, with failure backoff', () => {
 const rows=[{auto_discover:true}];
 assert.equal(discovery.canAuto(true,true,rows,1000,0),true);
 assert.equal(discovery.canAuto(false,true,rows,1000,0),false);
 assert.equal(discovery.canAuto(true,false,rows,1000,0),false);
 assert.equal(discovery.canAuto(true,true,rows,1000,2000),false);
 assert.equal(discovery.canAuto(true,true,[{auto_discover:false}],1000,0),false);
});
test('only approved auto records are scheduled and extra reply fields are dropped', () => {
 const rows=[{peer_id:'one',address:'10.1.1.1',source:'bth',auto_discover:true,manual_baseline:false,registered:true},{peer_id:'two',address:'10.1.1.2',source:'manual',auto_discover:false,manual_baseline:false,registered:true}];
 assert.equal(discovery.approvedChanges(rows).length,1);
 const parsed=discovery.parse(JSON.stringify({schema_version:1,ok:true,addresses:rows,custom_addresses:['10.1.1.1'],private_extra:'drop'}));
 assert.equal('private_extra' in parsed,false);
 assert.equal(discovery.parse('{'),null);
 assert.equal(discovery.parse(JSON.stringify({schema_version:1,ok:true,addresses:[],custom_addresses:[7]})),null);
});
