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
        if (!value) { console.error("NATIVE_FAIL sharing modes: " + label); Qt.quit(); return false }
        checks = checks.concat([label]); return true
    }
    function find(object, name, seen) {
        if (!object || seen.indexOf(object) !== -1) return null
        seen.push(object)
        if (typeof name === "function" ? name(object) : object.objectName === name) return object
        for (var key of ["children", "data"]) {
            var values = object[key]
            if (!values || typeof values.length !== "number") continue
            for (var value of values) { var found=find(value,name,seen);if(found)return found }
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
    Window {
        visible: true; width: 520; height: 800
        Item { id: anchor; width: 26; height: 26 }
        Plugin.Panel { id: panel; bar: fakeBar; anchorItem: anchor; settings: ({showTailscale:false}) }
    }
    Process {
        id: replaceScreenshot
        onExited: function(code) {
            if (!test.check(code === 0, "fixture replaces the reviewed screenshot")) return
            if (!test.check(service.submitSelection(), "explicit Send starts the reviewed transfer")) return
            panel.currentView = "Activity"
        }
    }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            if (++test.ticks > 500) {test.check(false,"bounded phase "+test.phase);return}
            var cancel=test.find(panel,"cancel-pending-files",[])
            if (test.phase===0 && service.devices.length===2 && service.appearance.ready) {
                panel.open();service.selectDevice("A")
                if(!test.check(panel.fileChooserOptions.useDesktopFileChooser===true && panel.fileChooserOptions.reviewFilesBeforeSend===false,"missing options default to desktop chooser and immediate submission"))return
                panel.settings={showTailscale:false,useDesktopFileChooser:false}
                if(!test.check(panel.chooseFiles() && service.draftTarget.peerId==="A","actual Panel forwards selected recipient and explicit recent-menu preference"))return
                service.selectDevice("B")
                panel.settings={showTailscale:false,useDesktopFileChooser:true,reviewFilesBeforeSend:true}
                if(!test.check(service.draftTarget.peerId==="A","open chooser retains recipient after navigation and settings change"))return
                test.phase=1
            } else if(test.phase===1 && service.activeOperation && !service.operationBusy) {
                if(!test.check(service.activeOperation.peerId==="A" && service.activeOperation.count===1 && service.activeOperation.accepted===1,"native recent menu inspects and submits once to captured A"))return
                service.clearOperations();service.selectDevice("A")
                if(!test.check(panel.chooseFiles(),"review preference starts actual desktop chooser"))return
                test.phase=2
            } else if(test.phase===2 && service.selectionState==="draft") {
                if(!test.check(service.selection.length===2 && service.draftTarget.peerId==="A" && !service.operationBusy && service.operations.length===0,"portal review holds complete batch without submission"))return
                panel.settings={showTailscale:false,useDesktopFileChooser:false,reviewFilesBeforeSend:false}
                service.selectDevice("B");test.phase=3
            } else if(test.phase===3) {
                if(++test.reviewTicks<8)return
                if(!test.check(!service.operationBusy && service.operations.length===0 && service.draftTarget.peerId==="A","later immediate setting and recipient changes do not submit or retarget review"))return
                if(!test.check(service.submitSelection(),"review requires explicit Send"))return
                test.phase=4
            } else if(test.phase===4 && service.activeOperation && !service.operationBusy) {
                if(!test.check(service.activeOperation.peerId==="A" && service.activeOperation.count===2 && service.activeOperation.accepted===2,"explicit review Send submits both files to captured A"))return
                service.clearOperations()
                if(!test.check(service.chooseFiles("A"),"compatibility call keeps portal and review"))return
                test.phase=5
            } else if(test.phase===5 && service.selectionState==="draft") {
                if(!test.check(service.selection.length===1 && service.operations.length===0 && !service.operationBusy,"compatibility chooser never submits implicitly"))return
                service.submitSelection();test.phase=6
            } else if(test.phase===6 && service.operationBusy && service.activeOperation.state==="submitting") {
                panel.setSectionExpanded("drop",false)
                for(var view of ["Devices","Send","Activity"]) {
                    panel.currentView=view
                    if(!test.check(cancel && cancel.visible && cancel.enabled && cancel.height>=44,"global Cancel stays available in "+view+" with File sharing collapsed"))return
                }
                if(!test.check(cancel.Accessible.role===Accessible.Button,"global Cancel exposes native button role"))return
                cancel.Accessible.pressAction()
                if(!test.check(service.cancellationRequested && cancel.visible && !cancel.enabled && cancel.text.indexOf("Cancelling")===0,"Cancel remains visible and disabled while cancellation is pending"))return
                cancel.Accessible.pressAction()
                if(!test.check(!cancel.enabled,"disabled cancellation accessibility action cannot repeat"))return
                test.phase=7
            } else if(test.phase===7 && !service.operationBusy) {
                if(!test.check(service.activeOperation.state==="cancellation_unconfirmed" && service.activeOperation.unknown===1,"in-flight native cancellation reports uncertainty"))return
                service.clearOperations()
                service.selectDevice("A")
                panel.currentView = "Devices"
                panel.settings = {quickActionsOrder: "review-screenshot"}
                test.phase = 8
            } else if (test.phase === 8) {
                var screenshotAction = test.find(panel, "quick-action-review-screenshot", [])
                if (!screenshotAction || !screenshotAction.visible || !screenshotAction.enabled) return
                screenshotAction.Accessible.pressAction()
                if (!test.check(panel.currentView === "Send" && service.draftTarget.peerId === "A",
                                "native screenshot action starts selection for the captured phone")) return
                service.selectDevice("B")
                test.phase = 9
            } else if (test.phase === 9 && service.selectionState === "draft") {
                if (!test.check(service.selection.length === 1 && service.selection[0].name === "owned-shot.png"
                                && service.draftTarget.peerId === "A" && service.operations.length === 0,
                                "one explicit screenshot reaches review without retargeting or submission")) return
                service.cancelFileTransfer()
                if (!test.check(service.selection.length === 0 && service.operations.length === 0,
                                "cancelling screenshot review submits nothing")) return
                service.selectDevice("A")
                panel.currentView = "Devices"
                test.phase = 10
            } else if (test.phase === 10) {
                var retryAction = test.find(panel, "quick-action-review-screenshot", [])
                if (!retryAction || !retryAction.visible || !retryAction.enabled) return
                retryAction.Accessible.pressAction()
                test.phase = 11
            } else if (test.phase === 11 && service.selectionState === "draft") {
                var path = service.selection[0].path
                replaceScreenshot.command = ["python3", "-c", "import os, sys; os.replace(sys.argv[1], sys.argv[2])",
                                             path + ".replacement", path]
                replaceScreenshot.running = true
                test.phase = 12
            } else if (test.phase === 12 && service.operations.length === 1 && !service.operationBusy) {
                var operation = service.operations[0]
                if (!test.check(operation.state === "submission_failed" && operation.error === "source-changed"
                                && operation.accepted === 0 && operation.failed === 1 && operation.delivery === "unknown",
                                "changed screenshot retains typed rejection and submission evidence")) return
                var activity = test.find(panel, function(item) {
                    return item.visible && typeof item.text === "string" && item.text.indexOf("KDE ID: A") >= 0
                }, [])
                if (!test.check(activity && activity.Accessible.name === activity.text
                                && activity.text.includes("Submission failed for 1 file.")
                                && activity.text.includes("A selected file changed. Choose the files again.")
                                && activity.text.includes("0/1 requests accepted. Delivery unknown."),
                                "Activity names the changed source and keeps failure, provider and delivery evidence")) return
                console.log("SHARING_MODES_PASS "+JSON.stringify(test.checks));console.log("NATIVE_PASS sharing modes");Qt.quit()
            }
        }
    }
}
