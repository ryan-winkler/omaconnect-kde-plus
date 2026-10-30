import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int waitTicks: 0
    property int configured: 0
    property var checks: []
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL modules: " + message); Qt.quit(); return false }
        checks = checks.concat([message]); return true
    }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        var children = item.children || []
        for (var i = 0; i < children.length; ++i) { var found = find(children[i], name); if (found) return found }
        return null
    }
    function toggle(id) { return find(view, "native-module-toggle-" + id) }
    QtObject {
        id: service
        property bool daemonAvailable: true
        property var selectedDevice: ({id:"A", paired:true, reachable:false})
    }
    Window {
        visible: true; width:520; height:900
        Components.NativeModuleSettings {
            id: view
            width:480
            service: service
            modules: [
                {id:"kdeconnect_share",name:"Share <b>plain</b>",description:"Receive files",hasConfiguration:true},
                {id:"kdeconnect_clipboard",name:"Clipboard",description:"Share clipboard",hasConfiguration:false},
                {id:"native_mismatch",name:"Mismatch",description:"Fake readback mismatch",hasConfiguration:true},
                {id:"native_unknown",name:"Unknown",description:"Fake uncertain write",hasConfiguration:false}
            ]
            onConfigureRequested: function(id) { if (id === "kdeconnect_share") test.configured++ }
        }
    }
    TestCase { id: events; when:false }
    Timer {
        interval:25; running:true; repeat:true
        onTriggered: {
            if (++test.ticks > 500) { test.check(false,"bounded module scenario finishes at phase " + test.phase); return }
            var backend = view.backend
            if (test.phase === 0) {
                if (!test.check(!backend.busy && !backend.refresh() && !backend.setEnabled("kdeconnect_share",false),"inactive page never dispatches")) return
                var job={operation:"read",peerId:"A",ids:["kdeconnect_share"]}
                var malformed=[
                    {state:"observed",peerId:"A",enabled:{kdeconnect_share:1},error:""},
                    {state:"observed",peerId:"B",enabled:{kdeconnect_share:true},error:""},
                    {state:"observed",peerId:"A",enabled:{other:true},error:""},
                    {state:"observed",peerId:"A",enabled:{},error:""},
                    {state:"unknown",peerId:"A",enabled:{},error:"submission-unknown"},
                    {state:"observed",peerId:"A",enabled:{kdeconnect_share:true},error:"",extra:true}
                ]
                for(var i=0;i<malformed.length;++i) if(!test.check(backend.parseReply(JSON.stringify(malformed[i]),job)===null,"untrusted reply case " + i + " is rejected"))return
                if(!test.check(backend.parseReply("x".repeat(65537),job)===null,"oversized reply is rejected"))return
                view.active = true; test.phase=1
            } else if (test.phase === 1 && !backend.busy && backend.known("kdeconnect_share")) {
                var share=test.toggle("kdeconnect_share")
                if (!test.check(share.checked && share.text === "On" && share.enabled,"paired offline device has observed On state")) return
                if (!test.check(test.toggle("kdeconnect_clipboard").text === "Off","native Off value is explicit")) return
                if (!test.check(share.Accessible.role === Accessible.CheckBox && share.Accessible.name === "Enable Share <b>plain</b>" && share.activeFocusOnTab,"native row exposes named checkbox and keyboard focus")) return
                var configure=test.find(view,"native-module-configure-kdeconnect_share")
                if (!test.check(configure.visible && !test.find(view,"native-module-configure-kdeconnect_clipboard").visible,"Configure appears only where native metadata supplies it")) return
                configure.Accessible.pressAction()
                configure.forceActiveFocus();events.keyClick(Qt.Key_Space,Qt.NoModifier,1)
                if (!test.check(test.configured === 2,"keyboard and AT Configure use exact module signal")) return
                share.forceActiveFocus(); events.keyClick(Qt.Key_Space,Qt.NoModifier,1)
                if (!test.check(share.checked && backend.busy,"keyboard request never toggles optimistically")) return
                test.phase=2
            } else if (test.phase === 2 && !backend.busy) {
                if (!test.check(backend.enabledStates.kdeconnect_share === false && test.toggle("kdeconnect_share").text === "Off","native write readback changes row to Off")) return
                test.toggle("kdeconnect_share").Accessible.toggleAction()
                if (!test.check(backend.busy && !test.toggle("kdeconnect_share").checked,"AT request also waits for native readback")) return
                test.phase=3
            } else if (test.phase === 3 && !backend.busy) {
                if (!test.check(test.toggle("kdeconnect_share").checked,"AT action confirms native On")) return
                backend.setEnabled("native_mismatch",true);test.phase=4
            } else if (test.phase === 4 && !backend.busy) {
                if (!test.check(backend.error === "readback-mismatch" && backend.enabledStates.native_mismatch === false,"mismatch shows actual native state")) return
                backend.setEnabled("native_unknown",true);test.phase=5
            } else if (test.phase === 5 && !backend.busy) {
                if (!test.check(backend.error === "submission-unknown" && !backend.known("native_unknown") && !test.toggle("native_unknown").enabled,"uncertain write clears only its observed value")) return
                if (!test.check(!backend.setEnabled("native_unknown",true),"unknown state cannot dispatch another write")) return
                backend.refresh();test.phase=6
            } else if (test.phase === 6 && !backend.busy && backend.known("native_unknown")) {
                if (!test.check(backend.enabledStates.native_unknown === false,"read-only refresh recovers observed state")) return
                service.selectedDevice=({id:"A",paired:false,reachable:true});test.phase=7
            } else if (test.phase === 7) {
                if (!test.check(!backend.ready && !backend.busy && !backend.refresh() && !backend.setEnabled("kdeconnect_share",false),"unpaired device cannot dispatch")) return
                service.selectedDevice=({id:"A",paired:true,reachable:false});test.phase=8
            } else if (test.phase === 8 && !backend.busy && backend.known("kdeconnect_share")) {
                service.daemonAvailable=false
                if (!test.check(!backend.setEnabled("kdeconnect_share",false),"unavailable daemon cannot dispatch")) return
                service.daemonAvailable=true;test.phase=9
            } else if (test.phase === 9 && !backend.busy && backend.known("kdeconnect_share")) {
                backend.refresh();test.phase=10
            } else if (test.phase === 10 && backend.busy) {
                service.selectedDevice=({id:"B",paired:true,reachable:false});test.phase=11
            } else if (test.phase === 11 && !backend.busy && backend.known("kdeconnect_share")) {
                if (!test.check(backend.peerId === "B" && backend.enabledStates.kdeconnect_share === false,"stale A read cannot overwrite selected B")) return
                service.selectedDevice=({id:"A",paired:true,reachable:false});test.phase=12
            } else if (test.phase === 12 && !backend.busy && backend.known("kdeconnect_share")) {
                backend.setEnabled("kdeconnect_share",false);test.waitTicks=0;test.phase=13
            } else if (test.phase === 13 && ++test.waitTicks >= 3) {
                service.selectedDevice=({id:"B",paired:true,reachable:false})
                service.selectedDevice=({id:"C",paired:true,reachable:false})
                if (!test.check(backend.busy && !backend.known("kdeconnect_share"),"initiated A write finishes without retargeting")) return
                test.phase=14
            } else if (test.phase === 14 && !backend.busy && backend.known("kdeconnect_share")) {
                if (!test.check(backend.peerId === "C" && backend.enabledStates.kdeconnect_share === false,"only latest selected target receives queued read")) return
                view.searchText="clipboard"
                if (!test.check(view.filteredModules.length === 1,"search filters full installed module catalogue")) return
                view.searchText=""
                if (!test.check(view.filteredModules.length === 4,"modules without configuration remain in catalogue")) return
                view.active=false;test.phase=15
            } else if (test.phase === 15) {
                if (!test.check(!backend.busy && !backend.refresh() && !backend.setEnabled("kdeconnect_share",true),"closed page cannot read or write")) return
                console.log("MODULE_CHECKS " + JSON.stringify(test.checks));console.log("NATIVE_PASS native module settings");Qt.quit()
            }
        }
    }
}
