import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "plugin" as Plugin
import "plugin/components" as Components
import "plugin/bridge" as Bridge

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property bool failed: false
    property bool slowBackendStarted: false
    FileView {
        path: Quickshell.env("NATIVE_COMMAND_LOG")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: if (text().indexOf("/slow") !== -1) test.slowBackendStarted=true
    }
    property var outcomes: []
    property var activeChooser: null
    function find(object, predicate, seen) {
        if (!object || seen.indexOf(object) !== -1) return null
        seen.push(object)
        if (predicate(object)) return object
        var lists = ["children", "data"]
        for (var i=0; i<lists.length; i++) {
            if (!(lists[i] in object)) continue
            var values = object[lists[i]]
            if (!values || typeof values.length !== "number") continue
            for (var j=0; j<values.length; j++) {
                var found = find(values[j],predicate,seen)
                if (found) return found
            }
        }
        var single = ["contentItem", "item"]
        for (var k=0;k<single.length;k++) {
            if (!(single[k] in object)) continue
            var foundItem = find(object[single[k]],predicate,seen)
            if (foundItem) return foundItem
        }
        return null
    }
    function click(label) {
        var button = find(panel,function(object) { return "text" in object && object.text === label && typeof object.clicked === "function" },[])
        check(!!button,"control exists: "+label)
        if (button) button.clicked()
    }
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL " + message); failed=true; Qt.quit(); }
        else outcomes = outcomes.concat([message])
    }
    Plugin.Service { id: service }
    QtObject {
        id: fakeFacade
        function serviceFor(id) { return null }
    }
    QtObject {
        id: fakeBar
        property var shell: fakeFacade
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
        function registerClickTarget(owner) {}
        function unregisterClickTarget(owner) {}
        function switchPanelFrom(owner, direction) { return false }
    }
    Item { id: anchor; width: 26; height: 26 }
    Plugin.BarWidget { id: widget; bar: fakeBar; settings: ({showTailscale:false}) }
    Window {
        id: previewWindow
        visible: false
        width: 500
        height: 700
        Plugin.Panel { id: panel; bar: fakeBar; anchorItem: anchor; settings: ({showTailscale:false}) }
        Components.SendSection { id: send; width: 400; service: service }
    }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if(test.failed) return
            test.ticks++
            if(test.ticks > 600) { test.check(false,"timeout phase="+test.phase); return }
            if(test.phase === 0 && service.appearance.ready && !service.appearance.busy && service.devices.length === 2) {
                test.check(Bridge.Bridge.service === service, "own-service bridge")
                test.check(widget.service === service && panel.service === service, "bar and panel bridge fallback")
                test.check(panel.viewNames.join(",") === "Devices,Send,Activity,Appearance", "all four views load")
                test.click("Appearance")
                test.check(panel.currentView === "Appearance", "Appearance tab action")
                test.activeChooser = test.find(panel,function(object) { return typeof object.openForBar === "function" },[])
                test.check(!!test.activeChooser,"panel icon chooser exists")
                test.click("Change bar icon")
                test.phase=1
            } else if(test.phase === 1 && !service.appearance.busy) {
                test.activeChooser.choose({mode:"preset",value:"laptop",render:"symbolic"})
                test.activeChooser.applyDraft()
                test.phase=2
            } else if(test.phase === 2 && !service.appearance.busy && service.appearance.snapshot.bar_icon.value === "laptop") {
                test.check(service.appearance.barIcon("A","phone").value === "laptop", "chooser Apply saves bar icon")
                service.appearance.refresh()
                test.phase=3
            } else if(test.phase === 3 && !service.appearance.busy) {
                test.check(service.appearance.snapshot.bar_icon.value === "laptop", "icon reload uses saved state")
                test.activeChooser.openForBar()
                test.activeChooser.choose({mode:"preset",value:"desktop"})
                test.activeChooser.reject()
                test.check(service.appearance.snapshot.bar_icon.value === "laptop", "chooser Cancel preserves state")
                test.phase=31
            } else if(test.phase === 31 && !service.appearance.busy) {
                test.check(service.appearance.setDeviceAppearance("A","Local phone",{mode:"preset",value:"desktop"}), "alias save starts")
                test.phase=4
            } else if(test.phase === 4 && !service.appearance.busy) {
                test.check(service.displayName(service.devices[0]) === "Local phone", "device alias uses own metadata")
                test.click("Send")
                test.check(panel.currentView === "Send", "Send tab action")
                service.selectDevice("A")
                test.click("Choose files")
                test.check(service.selectionState === "choosing", "explicit portal choose starts")
                test.phase=5
            } else if(test.phase === 5 && service.selectionState === "draft") {
                test.check(service.selection.length === 2 && service.selectionBytes === 7, "portal files reach review with real sizes")
                test.check(!service.operationBusy && service.operations.length === 0, "chooser close does not send")
                service.selectDevice("B")
                test.check(service.draftTarget.peerId === "A", "draft target survives selection change")
                test.check(service.submitSelection(), "explicit Send starts queue")
                test.phase=6
            } else if(test.phase === 6 && service.operationBusy) {
                service.clearActionState()
                service.selectDevice("A")
                service.selectDevice("B")
                test.check(service.operationBusy && service.activeOperation.peerId === "A", "active target survives device changes and clear")
                test.phase=7
            } else if(test.phase === 7 && !service.operationBusy && service.activeOperation) {
                test.check(service.activeOperation.state === "request_accepted" && service.activeOperation.accepted === 2, "two sequential KDE requests accepted")
                test.check(service.activeOperation.delivery === "unknown", "accepted does not claim delivery")
                test.check(JSON.stringify(service.operations).indexOf("/one") === -1, "activity excludes raw file paths")
                test.click("Activity")
                test.check(panel.currentView === "Activity", "Activity tab action")
                service.selectDevice("A")
                service.chooseFiles("A")
                test.phase=8
            } else if(test.phase === 8 && service.selectionState === "draft") {
                service.submitSelection()
                test.phase=9
            } else if(test.phase === 9 && test.slowBackendStarted && service.activeOperation && service.activeOperation.state === "submitting") {
                service.cancelOperation()
                test.phase=10
            } else if(test.phase === 10 && !service.operationBusy) {
                test.check(service.activeOperation.state === "cancellation_unconfirmed", "cancel after submission stays unconfirmed")
                service.clearOperations()
                test.check(service.operations.length === 0, "clear finished activity")
                test.click("Devices")
                test.check(panel.currentView === "Devices", "Devices tab action")
                service.openSyncthingPanel()
                test.phase=11
            } else if(test.phase === 11 && service.ownerPanelMessage.indexOf("unavailable") !== -1) {
                test.check(service.ownerPanelMessage.indexOf("Opened") === -1, "owner summon exit zero without confirmation stays unavailable")
                console.log("NATIVE_PASS "+JSON.stringify(test.outcomes))
                Qt.quit()
            }
        }
    }
}
