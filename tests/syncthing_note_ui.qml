import QtQuick
import QtQuick.Window
import Quickshell
import "components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property var checks: []
    property bool initialPrefill: false
    property var editor: null
    property var save: null
    property var remove: null
    property string idA: Array(8).fill("AAAAAAA").join("-")
    property string idB: Array(8).fill("BBBBBBB").join("-")
    property string idC: Array(8).fill("CCCCCCC").join("-")
    function check(value, message) {
        if (!value) { console.error("SYNCTHING_NOTE_FAIL " + message); Qt.quit(); return false }
        checks = checks.concat([message]); return true
    }
    function find(item, predicate) {
        if (predicate(item)) return item
        for (var i=0;i<item.children.length;i++) { var result=find(item.children[i],predicate); if(result)return result }
        return null
    }
    function button(name, oldLabel) {
        return find(section,function(item) { return item.objectName === name || ("text" in item && item.text === oldLabel) })
    }
    function typeId(value) {
        // Use the native text-control methods; direct JS assignment to text
        // would remove its QML binding and would not represent ordinary editing.
        editor.clear();editor.insert(0,value);editor.textEdited()
    }
    function click(item) { if (item && item.enabled) item.clicked() }
    QtObject {
        id: store
        property bool busy: false
        property string error: ""
        property var records: ({A:{syncthing_device_id:test.idA},B:{syncthing_device_id:test.idB}})
        property var calls: []
        property var pending: null
        signal saved()
        signal operationFailed(string message)
        function deviceAppearance(id) { return records[id] || {} }
        function linkSyncthing(id,value) {
            if (busy) return false
            calls=calls.concat([{id:id,value:value}]); pending={id:id,value:value}; busy=true;error="";return true
        }
        function finish() {
            var next=Object.assign({},records);next[pending.id]={syncthing_device_id:pending.value || null}
            records=next;pending=null;busy=false;saved()
        }
        function fail() { pending=null;busy=false;error="Owned save failure";operationFailed(error) }
    }
    QtObject {
        id: service
        property var appearance: store
        property var selectedDevice: ({id:"A",name:"Phone A"})
        property string ownerPanelMessage: ""
        property int ownerCalls: 0
        property int ownerArguments: -1
        property string syncthingDeviceId: ""
        property string syncthingState: ""
        property bool syncthingBusy: false
        property var pauseCalls: []
        property int readCalls: 0
        function readSyncthingPause(id) { readCalls++;syncthingDeviceId=id;syncthingState="active";return true }
        function setSyncthingPaused(id,paused) { pauseCalls=pauseCalls.concat([{id:id,paused:paused}]);syncthingState=paused?"paused":"active";return true }
        function openSyncthingPanel() { ownerCalls++;ownerArguments=arguments.length;ownerPanelMessage="Owned panel unavailable" }
    }
    Window {
        id:preview
        width:550;height:900;visible:true
        Components.SyncthingLinkSection {id:section;service:service;panelOpened:true;width:520}
    }
    Timer {
        interval:35;repeat:true;running:true
        onTriggered: {
            if (test.phase===0) {
                test.editor=test.find(section,function(item) {return "placeholderText" in item && item.placeholderText==="Full Syncthing device ID"})
                test.save=test.button("syncthing-save","Confirm these two identities")
                test.remove=test.button("syncthing-remove","Remove local link")
                if (!test.check(!!test.editor && !!test.save && !!test.remove,"native note controls load"))return
                test.initialPrefill=test.editor.text===test.idA
                test.typeId(test.idC);service.selectedDevice={id:"B",name:"Laptop B"};test.phase++
            } else if(test.phase===1) {
                test.click(test.save);test.phase++
            } else if(test.phase===2) {
                if(!test.check(!store.calls.some(function(row){return row.id==="B" && row.value===test.idC}),"A draft never saves to B after device change"))return
                if(!test.check(test.initialPrefill && test.editor.text===test.idB,"editor preloads and rebases to each saved identity"))return
                var saved=test.find(section,function(item){return item.objectName==="syncthing-saved-id"})
                if(!test.check(!!saved && saved.readOnly && saved.selectByMouse,"saved full ID has a native selectable field"))return
                saved.selectAll();if(!test.check(saved.selectedText===test.idB,"saved full ID can be selected for copying"))return
                test.typeId(test.idC);test.click(test.save);test.phase++
            } else if(test.phase===3) {
                if(!test.check(store.pending.id==="B" && store.pending.value===test.idC,"save captures its reviewed KDE peer"))return
                if(!test.check(section.linkedId===test.idB && section.feedback.toLowerCase().indexOf("saved")<0,"save request does not fabricate saved state"))return
                store.busy=false;test.phase++
            } else if(test.phase===4) {
                if(!test.check(!test.save.enabled && section.linkedId===test.idB,"busy ending alone does not confirm a save"))return
                store.finish();test.phase++
            } else if(test.phase===5) {
                if(!test.check(section.linkedId===test.idC && section.feedback.toLowerCase().indexOf("saved")>=0,"matching saved readback confirms the note"))return
                test.click(test.remove);test.phase++
            } else if(test.phase===6) {
                if(!test.check(store.pending.id==="B" && store.pending.value==="" && section.linkedId===test.idC,"removal waits for readback and keeps its target"))return
                store.fail();test.phase++
            } else if(test.phase===7) {
                if(!test.check(section.linkedId===test.idC && section.feedback.toLowerCase().indexOf("removed")<0,"failed removal preserves the displayed saved note"))return
                test.click(test.remove);store.finish();test.phase++
            } else if(test.phase===8) {
                if(!test.check(section.linkedId==="" && test.editor.text==="" && section.feedback.toLowerCase().indexOf("removed")>=0,"confirmed removal clears only the local note"))return
                test.typeId(test.idC);test.click(test.save);service.selectedDevice={id:"A",name:"Phone A"};test.phase++
            } else if(test.phase===9) {
                store.finish();test.phase++
            } else if(test.phase===10) {
                if(!test.check(section.linkedId===test.idA && test.editor.text===test.idA && store.records.B.syncthing_device_id===test.idC,"in-flight B save cannot change the selected A note"))return
                if(!test.check(section.feedback.toLowerCase().indexOf("previous")>=0,"late success names the previous-device context"))return
                test.typeId(test.idC);test.click(test.save);store.fail();test.phase++
            } else if(test.phase===11) {
                if(!test.check(section.linkedId===test.idA && test.editor.text===test.idC && section.feedback.toLowerCase().indexOf("saved")<0,"save failure retains the draft without claiming persistence"))return
                test.click(test.button("syncthing-owner","Open existing Syncthing panel"));test.phase++
            } else if(test.phase===12) {
                if(!test.check(service.ownerCalls===1 && service.ownerArguments===0,"owner link opens the generic existing panel"))return
                var message=test.find(section,function(item){return "text" in item && item.text==="Owned panel unavailable"})
                if(!test.check(!!message && message.visible,"unavailable owner feedback stays visible"))return
                var before=JSON.stringify(store.records),count=store.calls.length;section.visible=false;section.visible=true
                if(!test.check(JSON.stringify(store.records)===before && store.calls.length===count,"hiding the section never removes metadata"))return
                var pause=test.button("syncthing-pause","Pause in Syncthing"),state=test.find(section,function(item){return item.objectName==="syncthing-pause-state"})
                if(!test.check(service.syncthingDeviceId===test.idA && !!pause && pause.visible && pause.enabled && state.text.indexOf("not paused")>=0,"linked device reads its Syncthing pause state in words"))return
                test.click(pause)
                if(!test.check(service.pauseCalls.length===1 && service.pauseCalls[0].id===test.idA && service.pauseCalls[0].paused && pause.text==="Resume in Syncthing","pause targets only the linked ID and offers resume"))return
                service.syncthingState="unknown"
                if(!test.check(!pause.enabled && state.text.indexOf("unknown")>=0,"unknown Syncthing state disables pause"))return
                var reads=service.readCalls
                section.panelOpened=false;section.readSyncState()
                if(!test.check(service.readCalls===reads,"closed panel never starts a state read"))return
                section.panelOpened=true
                if(!test.check(service.readCalls===reads+1,"reopening the panel refreshes linked state"))return
                console.log("SYNCTHING_NOTE_PASS",JSON.stringify(test.checks));Qt.quit();test.phase++
            }
        }
    }
}
