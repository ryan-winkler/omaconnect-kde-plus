import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "plugin" as Plugin
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int staged: 0
    property int windows: 0
    property var checks: []
    function check(value,label) {
        if(!value){console.error("NATIVE_FAIL inline send: "+label);Qt.quit();return false}
        checks=checks.concat([label]);return true
    }
    function find(item,name) {
        if(!item)return null
        if(item.objectName===name)return item
        for(var child of item.children || []) {var found=find(child,name);if(found)return found}
        if(item.item){var loaded=find(item.item,name);if(loaded)return loaded}
        return null
    }
    function event(urls,actions) {
        return {hasUrls:true,urls:urls,supportedActions:actions,accepted:false,action:Qt.IgnoreAction,
            accept:function(action){this.accepted=true;this.action=action}}
    }
    Plugin.Service {id: service}
    QtObject {
        id: panel
        property var service: service
        readonly property var device: service.selectedDevice
        function openSendWindow(){test.windows++}
    }
    QtObject {
        id: fakeBar
        property var shell: ({serviceFor:function(){return service}})
        property bool vertical: false
        property bool foregroundAnimationEnabled: false
        property int barSize: 26
        property string position: "top"
        property string fontFamily: "sans-serif"
        property color barForeground: "#ffffff"
        property color foreground: "#ffffff"
        property color urgent: "#ff5555"
        property int width: 1000
        property int height: 26
        function hideTooltip(owner){}
        function showTooltip(owner,text,options){}
        function registerClickTarget(owner){}
        function unregisterClickTarget(owner){}
    }
    Window {
        visible:true;width:520;height:800
        Components.InlineSendSection {id:inlineSend;width:480;panel:panel;onFilesStaged:test.staged++}
        Plugin.BarWidget {id:barWidget;y:700;bar:fakeBar;settings:({})}
    }
    TestCase {id:events;when:false}
    Timer {
        interval:40;running:true;repeat:true
        onTriggered:{
            if(++test.ticks>200){test.check(false,"bounded fixture finishes at phase "+test.phase);return}
            var zone=test.find(inlineSend,"inline-send-drop-zone")
            var choose=test.find(inlineSend,"inline-send-choose-files")
            var keep=test.find(inlineSend,"inline-send-open-window")
            var icon=test.find(barWidget,"bar-file-drop-area")
            var host=test.find(barWidget,"fake-hover-panel")
            if(test.phase===0 && service.devices.length===2 && host && service.appearance.ready){
                service.selectDevice("A")
                if(!test.check(zone && choose && keep && choose.enabled,"inline drop and keyboard alternatives load"))return
                if(!test.check(icon.acceptDrag(test.event([Qt.resolvedUrl("one")],Qt.CopyAction|Qt.MoveAction)) && host.hoverOpens===1 && host.opened,"Copy URL hover opens the drop target without toggling"))return
                if(!test.check(service.selection.length===0 && service.draftTarget===null && !service.operationBusy,"hover does not stage or submit files"))return
                if(!test.check(!icon.acceptDrag(test.event([Qt.resolvedUrl("one")],Qt.MoveAction)) && host.hoverOpens===1,"Move-only hover never opens the target"))return
                var drop=test.event([Qt.resolvedUrl("one")],Qt.CopyAction|Qt.MoveAction)
                if(!test.check(zone.acceptFiles(drop) && drop.action===Qt.CopyAction && test.staged===1,"inline zone forwards accepted Copy review"))return
                test.phase=1
            }else if(test.phase===1 && service.selectionState==="draft"){
                var review=test.find(inlineSend,"inline-send-review")
                if(!test.check(review.visible && !review.showHeading && review.target.peerId==="A" && review.files.length===1,"review appears beneath the same drop zone for captured A"))return
                service.selectDevice("B")
                if(!test.check(service.draftTarget.peerId==="A" && !zone.ready && !choose.enabled,"selection change cannot retarget or replace reviewed files"))return
                if(!test.check(!zone.acceptFiles(test.event([Qt.resolvedUrl("two")],Qt.CopyAction)) && test.staged===1,"existing draft refuses another drop"))return
                keep.Accessible.pressAction()
                if(!test.check(test.windows===1 && service.draftTarget.peerId==="A" && service.operations.length===0 && !service.operationBusy,"persistent-window route preserves review and never sends"))return
                service.cancelDraft();test.phase=2
            }else if(test.phase===2 && service.selectionState!=="draft" && choose.enabled){
                choose.forceActiveFocus();events.keyClick(Qt.Key_Space,Qt.NoModifier,1);test.phase=3
            }else if(test.phase===3 && service.selectionState==="draft"){
                if(!test.check(service.draftTarget.peerId==="B" && service.selection.length===2 && service.operations.length===0 && !service.operationBusy,"keyboard Choose files stages portal review for current B without sending"))return
                service.cancelDraft()
                if(!test.check(!zone.acceptFiles(test.event(["https://example.invalid/file"],Qt.CopyAction)) && test.staged===1,"controller refusal is not an accepted inline drop"))return
                service.devices=[]
                if(!test.check(!zone.ready && !choose.enabled && !icon.acceptDrag(test.event([Qt.resolvedUrl("one")],Qt.CopyAction)),"missing recipient refuses drop, keyboard and hover"))return
                console.log("INLINE_SEND_PASS "+JSON.stringify(test.checks));console.log("NATIVE_PASS inline send");Qt.quit()
            }
        }
    }
}
