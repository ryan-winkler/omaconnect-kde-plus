import QtQuick
import Quickshell
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int returns: 0
    property var checks: []
    function check(value, label) {
        if (!value) { console.error("NATIVE_FAIL send window: " + label); Qt.quit(); return false }
        checks=checks.concat([label]);return true
    }
    function find(object, name) {
        if (!object) return null
        if (object.objectName===name) return object
        var children=object.children || []
        for(var i=0;i<children.length;i++){var found=find(children[i],name);if(found)return found}
        return null
    }
    QtObject {
        id: fakeService
        property var draftTarget: null
        property bool operationBusy: false
        property string selectionState: "idle"
        property string selectionError: ""
        property var selection: []
        property int selectionBytes: 0
        property var operations: []
        property var dropCalls: []
        function stageDroppedFiles(id, urls) { dropCalls=dropCalls.concat([{id:id,urls:urls}]);return true }
        function submitSelection() { test.check(false,"no implicit send") }
        function cancelDraft() { test.check(false,"window close does not cancel draft") }
        function chooseFiles(id) {}
        function clearOperations() {}
        function cancelOperation() {}
    }
    Components.SendWindow {
        id: send
        service: fakeService
        device: ({id:"A",name:"Selected phone",paired:true,reachable:true,capabilities:{file:true}})
        onReturnToPanelRequested: test.returns++
    }
    Timer {
        interval: 50;repeat:true;running:true
        onTriggered: {
            if(++test.ticks>100){test.check(false,"window scenario completes");return}
            if(test.phase===0){
                if(!test.check(!send.visible && send.transientParent===null,"normal send window starts hidden and has no popover transient parent"))return
                send.openSend();test.phase=1
            }else if(test.phase===1 && send.visible){
                if(!test.check(send.minimumWidth===480 && send.minimumHeight===360,"send window is resizable with usable minimum bounds"))return
                var zone=test.find(send.contentItem,"send-window-drop-zone")
                var drop={hasUrls:true,urls:["file:///tmp/a"],supportedActions:Qt.CopyAction|Qt.MoveAction,accepted:false,action:Qt.IgnoreAction,accept:function(action){this.action=action;this.accepted=true}}
                if(!test.check(zone && zone.acceptFiles(drop) && drop.action===Qt.CopyAction && fakeService.dropCalls[0].id==="A","persistent send window reuses copy-only review drop zone"))return
                fakeService.draftTarget=({peerId:"A",peerName:"Reviewed phone",provider:"kdeconnect"})
                fakeService.selectionState="draft";fakeService.selection=[{name:"example",size:1}];fakeService.selectionBytes=1
                send.device=({id:"B",name:"Other phone",paired:true,reachable:true,capabilities:{file:true}})
                test.phase=2
            }else if(test.phase===2){
                var recipient=test.find(send.contentItem,"send-window-recipient")
                if(!test.check(recipient.text.indexOf("Reviewed phone")!==-1 && recipient.text.indexOf("Other phone")===-1,"window keeps reviewed target visible after device navigation"))return
                send.close();test.phase=3
            }else if(test.phase===3 && !send.visible){
                if(!test.check(fakeService.draftTarget.peerId==="A" && fakeService.selection.length===1,"closing window preserves service draft"))return
                send.openSend();test.phase=4
            }else if(test.phase===4 && send.visible){
                send.returnToDevices();test.phase=5
            }else if(test.phase===5 && !send.visible){
                if(!test.check(test.returns===1 && fakeService.draftTarget.peerId==="A","back to devices returns once without cancel or send"))return
                console.log("SEND_WINDOW_PASS "+JSON.stringify(test.checks));console.log("NATIVE_PASS send window");Qt.quit()
            }
        }
    }
}
