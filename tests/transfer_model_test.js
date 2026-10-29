const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const model = {};
vm.createContext(model);
vm.runInContext(fs.readFileSync(path.join(root, 'TransferModel.js'), 'utf8').replace(/^\.pragma library\s*/m, ''), model);
const files = [{path: '/private/name', size: 3}, {path: '/private/other', size: 4}];
let op = model.create('one', {peerId:'A', peerName:'Phone', provider:'kdeconnect'}, files, 10);
assert.equal(op.peerId, 'A');
assert.equal(op.state, 'queued');
op = model.record(op, 0, 'request_accepted', '', 11);
assert.equal(op.accepted, 1);
assert.equal(op.delivery, 'unknown');
op = model.record(op, 1, 'submission_unknown', 'submission-unknown', 12);
assert.equal(op.state, 'submission_unknown');
assert.ok(!JSON.stringify(op).includes('/private'));
let history = [];
for (let n = 0; n < 55; n++) history = model.remember(history, Object.assign({}, op, {id:String(n)}));
assert.equal(history.length, 50);
assert.equal(history[0].id, '54');
assert.equal(model.formatBytes(2 ** 40), '1.00 TiB');
// Run the actual QML functions against process doubles to catch selection coupling.
const qml = fs.readFileSync(path.join(root, 'KdeConnectController.qml'), 'utf8');
function extract(name) {
 const start = qml.indexOf('    function ' + name + '(');
 assert.ok(start >= 0, name);
 const brace = qml.indexOf('{', start);
 let depth = 1, end = brace + 1;
 for (; depth; end++) { if (qml[end] === '{') depth++; if (qml[end] === '}') depth--; }
 return qml.slice(start, end);
}
const context = {
 selectedDeviceId:'A', devices:[{id:'A'}, {id:'B'}], activeOperation:{id:'one',peerId:'A'}, operationBusy:true,
 fileBusy:true, fileTransferState:'submitting', fileTransferMessage:'Submitting', fileTransferError:'',
 actionState:'', actionMessage:'', actionError:'', actionGeneration:0, remoteCommands:[], commandsLoading:false,
 mediaState:{}, mediaLoading:false, mediaRefreshPending:false,
 mediaStatusProcess:{running:false},mediaActionProcess:{running:false},mediaPlayerProcess:{running:false},actionProcess:{running:false},commandsProcess:{running:false},
 fileTransferProcess:{running:true},filePickerProcess:{running:false},
 deviceById:id => ({id, paired:false}), emptyMediaState:()=>({})
};
vm.createContext(context);
vm.runInContext(extract('clearActionState') + '\n' + extract('selectDevice'), context);
context.selectDevice('B');
assert.equal(context.fileTransferProcess.running, true);
assert.equal(context.activeOperation.peerId, 'A');
assert.equal(context.fileBusy, true);
context.clearActionState();
assert.equal(context.fileBusy, true);
assert.equal(context.fileTransferState, 'submitting');
assert.ok(!qml.includes('"File sent"'));
// Exercise the real batch functions, including review, immutable peer and timeout.
const pending = [];
Object.assign(context, {
 TransferModel:model, Qt:{callLater:callback=>pending.push(callback)}, root:context,
 devices:[{id:'A',name:'Original phone',paired:true,reachable:true,capabilities:{file:true}}, {id:'B',name:'Other phone',paired:true,reachable:true,capabilities:{file:true}}],
 selectedDeviceId:'A',selection:[],selectionBytes:0,selectionState:'idle',selectionError:'',draftTarget:null,
 selectionGeneration:0,fileTransferGeneration:0,operationSequence:0,operations:[],activeOperation:null,operationBusy:false,
 fileInspectProcess:{running:false,signal(){}},filePickerProcess:{running:false,signal(){}},
 fileTransferProcess:{running:false,signal(){this.signalled=true;}}
});
context.deviceById = id => context.devices.find(device=>device.id===id);
context.canAct = id => !!context.deviceById(id);
vm.runInContext(['chooseFiles','applySelection','selectionErrorText','cancelDraft','submitSelection','updateOperation','finishOperation','cancelRemaining','submitNextFile','applySubmissionLine','submissionExited','cancelOperation','clearOperations'].map(extract).join('\n'), context);
assert.equal(context.chooseFiles('A'), true);
context.filePickerProcess.running=false;
const chosen = [{path:'/private/one',name:'one',size:1},{path:'/private/two',name:'two',size:2},{path:'/private/three',name:'three',size:3}];
context.applySelection(JSON.stringify({state:'selected', files:chosen}), 0, context.selectionGeneration);
assert.equal(context.selectionState, 'draft');
assert.equal(context.fileTransferProcess.running, false, 'closing chooser must not send');
context.selectDevice('B');
assert.equal(context.draftTarget.peerId, 'A');
assert.ok(Object.isFrozen(context.draftTarget));
assert.equal(context.submitSelection(), true);
assert.equal(context.activeOperation.peerId, 'A');
assert.equal(context.selection.length, 0);
pending.shift()();
const firstPayload = JSON.parse(context.fileTransferProcess.payload);
assert.equal(firstPayload.peerId,'A');
assert.equal(firstPayload.file.path, '/private/one');
const operationId = context.activeOperation.id;
context.applySubmissionLine('{"event":"submitting"}', operationId);
context.applySubmissionLine('{"state":"request_accepted","error":""}', operationId);
context.fileTransferProcess.running=false;
context.submissionExited(operationId);
pending.shift()();
assert.equal(JSON.parse(context.fileTransferProcess.payload).file.path, '/private/two');
context.applySubmissionLine('{"event":"submitting"}', operationId);
context.applySubmissionLine('{"state":"submission_unknown","error":"submission-unknown"}', operationId);
context.fileTransferProcess.running=false;
context.submissionExited(operationId);
assert.equal(context.operationBusy, false);
assert.equal(context.activeOperation.accepted,1);
assert.equal(context.activeOperation.unknown,1);
assert.equal(context.activeOperation.cancelled,1);
assert.equal(context.activeOperation.state,'submission_unknown');
assert.equal(pending.length,0,'ambiguous timeout must stop without automatic retry');
assert.ok(!JSON.stringify(context.operations).includes('/private'));
// Cancel while queued is confirmed before submit, with zero backend launches.
context.chooseFiles('A'); context.filePickerProcess.running=false;
context.applySelection(JSON.stringify({state:'selected',files:chosen}),0,context.selectionGeneration);
context.submitSelection();
context.cancelOperation();
pending.shift()();
assert.equal(context.fileTransferProcess.running,false);
assert.equal(context.activeOperation.state,'cancelled_before_submit');
assert.equal(context.activeOperation.cancelled,3);
