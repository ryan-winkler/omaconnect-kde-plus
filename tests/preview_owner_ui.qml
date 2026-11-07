import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "plugin" as Plugin

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int reviewTicks: 0
    property var checks: []
    function check(value, label) {
        if (!value) { console.error("NATIVE_FAIL preview owner: " + label); Qt.quit(); return false }
        checks = checks.concat([label]); return true
    }
    function find(object, name, seen) {
        if (!object || seen.indexOf(object) !== -1) return null
        seen.push(object)
        if (object.objectName === name) return object
        for (var key of ["children", "data"]) {
            try {
                var values = object[key]
                if (!values || typeof values.length !== "number") continue
                for (var value of values) { var found=find(value,name,seen);if(found)return found }
            } catch (error) { continue }
        }
        for (var single of ["contentItem", "item", "footer"]) {
            var nested=object[single]
            if(nested){var child=find(nested,name,seen);if(child)return child}
        }
        return null
    }
    Plugin.Service { id: service }
    QtObject {
        id: facade
        function serviceFor(id) { return service }
    }
    QtObject {
        id: fakeBar
        property var shell: facade
        property var activePopout: null
        function requestPopout(owner) { activePopout=owner }
        function releasePopout(owner) { if(activePopout===owner)activePopout=null }
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
        function hideTooltip(owner) {}
        function showTooltip(owner,text,options) {}
        function registerClickTarget(owner) {}
        function unregisterClickTarget(owner) {}
        function switchPanelFrom(owner,direction) { return false }
    }
    property var temporaryPanel: null
    property int firstGeneration: -1
    Process {
        id: replacePreview
        command: ["python3", "-c", "from pathlib import Path; folder = Path.home() / 'Pictures'; (folder / 'owned.png.replacement').replace(folder / 'owned.png')"]
        onExited: function(code) {
            if (test.check(code === 0, "synthetic image replaced after preview became ready")) test.phase = 10
        }
    }
    Component {
        id: panelFactory
        Plugin.Panel { bar: fakeBar; anchorItem: anchor; settings: ({showTailscale:false}) }
    }
    Window {
        visible: true; width: 1100; height: 800
        Item { id: anchor; width: 26; height: 26 }
        Plugin.Panel { id: first; bar: fakeBar; anchorItem: anchor; settings: ({showTailscale:false}) }
        Plugin.Panel { id: second; bar: fakeBar; anchorItem: anchor; settings: ({showTailscale:false}) }
    }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            if (++test.ticks > 450) { test.check(false,"bounded ownership phase "+test.phase); return }
            var a=test.find(first,"image-preview-window",[])
            var b=test.find(second,"image-preview-window",[])
            if(test.phase===0 && service.devices.length===2 && service.appearance.ready && a && b) {
                service.selectDevice("A")
                if(!test.check(first.chooseFiles() && first.ownsPreview && !second.ownsPreview,"first chooser records one originating panel"))return
                second.open();test.firstGeneration=service.selectionGeneration;test.phase++
            } else if(test.phase===1 && service.selectionState==="preview" && a.visible) {
                if(!test.check(first.ownsPreview && !second.ownsPreview && !b.visible && second.opened,"only owner opens preview and closes its own dropdown"))return
                var hidden=test.find(b.contentItem,"image-preview-image",[])
                if(!test.check(!b.canConfirm && String(hidden.source)==="","unowned window decodes no image and cannot confirm"))return
                b.confirmRequested(service.previewCandidates[0]);b.cancelRequested()
                if(!test.check(service.selectionState==="preview" && !second.backToFiles(),"unowned panel signals cannot send cancel or navigate another selection"))return
                a.backRequested()
                if(!test.check(first.ownsPreview && first.previewGeneration>test.firstGeneration,"Back renews only the same owner's generation"))return
                test.phase++
            } else if(test.phase===2 && service.selectionState==="preview" && a.visible) {
                if(!test.check(!b.visible && first.ownsPreview,"Back result returns only to original panel"))return
                a.cancelRequested();test.phase++
            } else if(test.phase===3 && service.selectionState==="idle") {
                var send=test.find(second,"send-window",[])
                if(!test.check(send.chooseFiles() && second.ownsPreview && !first.ownsPreview,"Send window chooser transfers ownership to its panel"))return
                test.phase++
            } else if(test.phase===4 && service.selectionState==="preview" && b.visible) {
                if(!test.check(!a.visible && !a.canConfirm && second.ownsPreview,"next originating panel is sole preview owner"))return
                b.cancelRequested();test.phase++
            } else if(test.phase===5 && service.selectionState==="idle") {
                test.temporaryPanel=panelFactory.createObject(null)
                if(!test.check(test.temporaryPanel.chooseFiles(),"temporary panel starts owned chooser"))return
                test.temporaryPanel.destroy();test.temporaryPanel=null;test.phase++
            } else if(test.phase===6 && service.selectionState==="idle" && !service.selectionCancelling) {
                if(!test.check(!service.draftTarget && !service.operationBusy,"destroyed chooser owner releases its unfinished selection"))return
                test.temporaryPanel=panelFactory.createObject(null)
                if(!test.check(test.temporaryPanel.chooseFiles(),"temporary panel starts second chooser"))return
                test.phase++
            } else if(test.phase===7 && service.selectionState==="preview") {
                test.temporaryPanel.destroy();test.temporaryPanel=null;test.phase++
            } else if(test.phase===8 && service.selectionState==="idle") {
                if(!test.check(!service.draftTarget && service.operations.length===0,"destroyed preview owner leaves no orphan preview or submission"))return
                if(!test.check(first.chooseFiles(),"owner starts a fresh chooser to test the loaded image"))return
                test.phase=9
            } else if(test.phase===9 && a.canConfirm) {
                service.selectDevice("B")
                replacePreview.running=true
                test.phase=90
            } else if(test.phase===10) {
                if(!test.check(a.canConfirm && service.draftTarget.peerId==="A","cached preview still shows the original reviewed recipient"))return
                a.confirm()
                test.phase=11
            } else if(test.phase===11 && service.selectionState==="idle") {
                var failedSend=test.find(first,"send-window",[])
                if(!test.check(failedSend.visible && service.selectionError==="A selected file changed. Choose the files again."
                        && service.draftTarget.peerId==="A" && service.selection.length===0 && service.operations.length===0,
                        "replaced image shows choose-again feedback without review or submission"))return
                console.log("PREVIEW_OWNER_PASS "+JSON.stringify(test.checks));console.log("NATIVE_PASS preview owner");Qt.quit()
            }
        }
    }
}
