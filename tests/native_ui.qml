import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "plugin" as Plugin
import "plugin/components" as Components
import "plugin/bridge" as Bridge

ShellRoot {
    id: test
    readonly property bool desktopMode: Quickshell.env("OMACONNECT_DESKTOP_VALIDATION") === "1"
    property int captures: 0
    function capture(name) {
        var body = find(panel,function(object) { return object.objectName === "omaconnect-content" },[])
        if (body) body.grabToImage(function(result) { result.saveToFile(Quickshell.env("NATIVE_COMMAND_LOG").replace("commands.jsonl", "desktop-"+name+".png")); test.captures++ })
    }
    function stageIconDrop() {
        var receiver = test.find(widget,function(object) { return object.objectName === "bar-file-drop-area" },[])
        var event = {hasUrls:true, urls:[Qt.resolvedUrl("one")], supportedActions:Qt.CopyAction|Qt.MoveAction, accepted:false, action:Qt.IgnoreAction,
            accept:function(value) { this.action=value;this.accepted=true }}
        var result = receiver ? receiver.acceptFiles(event) : false
        test.check(result && event.action===Qt.CopyAction, "actual bar drop stages Copy review: result=" + result + ",action=" + event.action + ",expected=" + Qt.CopyAction)
        if(test.failed) return
        test.phase=13
    }
    Timer { interval: 300; running: test.desktopMode; onTriggered: panel.open() }
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
        var single = ["contentItem", "item", "footer"]
        for (var k=0;k<single.length;k++) {
            if (!(single[k] in object)) continue
            var foundItem = find(object[single[k]],predicate,seen)
            if (foundItem) return foundItem
        }
        return null
    }
    function click(label) {
        var viewIndex = panel.viewNames.indexOf(label)
        if (viewIndex >= 0) {
            var trigger = find(panel,function(object) { return object.objectName === "daily-view-menu" },[])
            if (trigger) trigger.clicked()
        }
        var button = find(panel,function(object) { return viewIndex >= 0 ? object.objectName === "daily-route-" + viewIndex : "text" in object && object.text === label && typeof object.clicked === "function" },[])
        check(!!button,"control exists: "+label)
        if (button) button.clicked()
    }
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL " + message); failed=true; Qt.quit(); return false }
        outcomes = outcomes.concat([message])
        return true
    }
    Plugin.Service { id: service }
    QtObject {
        id: fakeFacade
        function serviceFor(id) { return null }
    }
    QtObject {
        id: fakeBar
        property var shell: fakeFacade
        property var activePopout: null
        function requestPopout(owner) { activePopout = owner }
        function releasePopout(owner) { if (activePopout === owner) activePopout = null }
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
        function showTooltip(owner, text, options) {}
        function registerClickTarget(owner) {}
        function unregisterClickTarget(owner) {}
        function switchPanelFrom(owner, direction) { return false }
    }
    Window {
        id: previewWindow
        title: "OmaConnect validation — sample devices"
        // Offscreen Qt also needs a visible window to instantiate ListView rows.
        visible: true
        width: 500
        height: test.desktopMode ? 60 : 700
        Item { id: anchor; width: 26; height: 26 }
        Plugin.BarWidget { id: widget; bar: fakeBar; settings: ({showTailscale:false}) }
        Plugin.Panel { id: panel; bar: fakeBar; anchorItem: anchor; settings: ({showTailscale:false}) }
        Components.SendSection { id: send; visible: !test.desktopMode; width: 400; service: service }
    }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if(test.failed) return
            test.ticks++
            if(test.ticks > 600) { test.check(false,"timeout phase="+test.phase); return }
            if(test.phase === 0 && (!test.desktopMode || panel.opened) && service.appearance.ready && !service.appearance.busy && service.devices.length === 2) {
                // ListView delegates are created on the next layout pass.
                if (!test.find(panel,function(object) { return object.objectName === "device-settings-B" },[])) { panel.open();return }
                test.check(Bridge.Bridge.service === service, "own-service bridge")
                test.check(widget.service === service && panel.service === service, "bar and panel bridge fallback")
                test.check(!!test.find(widget,function(object) { return object.objectName === "bar-file-drop-area" },[]), "actual bar icon installs the shared file-drop target")
                test.check(panel.viewNames.join(",") === "Devices,Send,Activity", "all three daily views load")
                test.check(!panel.syncthingVisible && panel.savedAddressesVisible, "optional Syncthing starts hidden while saved addresses remain available")
                panel.settings = {showSavedAddresses:false,showSyncthingLinks:true,showNetworkControls:false,mediaStartExpanded:false,commandsStartExpanded:true}
                test.check(!panel.savedAddressesVisible && panel.syncthingVisible && !panel.networkControlsVisible, "saved section visibility respects settings")
                panel.settings = {showTailscale:false}
                test.capture("devices")

                var deviceGear = test.find(panel,function(object) { return object.objectName === "device-settings-B" },[])
                test.check(deviceGear && deviceGear.focusable && deviceGear.width>=44 && deviceGear.Accessible.name.indexOf("Other phone")!==-1,"paired device gear has a named keyboard target")
                if (deviceGear) deviceGear.clicked()
                test.check(panel.settingsWindow.visible && panel.settingsWindow.currentPage==="Device features" && service.selectedDeviceId==="B","device gear opens Plus features for that exact device")
                test.check(!service.nativeAppOpening,"device gear does not launch native settings implicitly")
                panel.settingsWindow.closeSettings()
                var headerGear = test.find(panel,function(object) { return object.objectName === "selected-device-settings" },[])
                if (headerGear) headerGear.clicked()
                test.check(headerGear && panel.settingsWindow.currentPage==="Device features" && service.selectedDeviceId==="B","header gear follows the same Plus device-settings route")
                panel.settingsWindow.closeSettings()
                var settingsControl = test.find(panel, function(object) { return object.objectName === "daily-plus-settings" }, [])
                test.check(!!settingsControl, "compact settings control exists")
                if (settingsControl) settingsControl.clicked()
                test.check(panel.settingsWindow.visible, "dedicated settings window opens")
                test.activeChooser = test.find(panel.settingsWindow,function(object) { return typeof object.openForBar === "function" },[])
                test.check(!!test.activeChooser,"settings icon chooser exists")
                test.click("Change bar icon")
                test.phase=1
            } else if(test.phase === 1 && !service.appearance.busy) {
                if(!test.check(test.activeChooser.visible,"settings action opens the actual icon chooser"))return
                test.activeChooser.choose({mode:"preset",value:"laptop",render:"symbolic"})
                var apply=test.find(test.activeChooser,function(object){return object.objectName==="appearance-apply"},[])
                if(!test.check(apply && apply.Accessible.role===Accessible.Button,"icon chooser exposes an accessible Apply button"))return
                apply.Accessible.pressAction()
                if (test.activeChooser.pendingApply) test.phase=2
            } else if(test.phase === 2 && !service.appearance.busy && service.appearance.snapshot.bar_icon.value === "laptop") {
                test.check(service.appearance.barIcon("A","phone").value === "laptop", "chooser Apply saves bar icon")
                service.appearance.refresh()
                test.phase=3
            } else if(test.phase === 3 && !service.appearance.busy) {
                test.check(service.appearance.snapshot.bar_icon.value === "laptop", "icon reload uses saved state")
                test.activeChooser.openForBar()
                test.activeChooser.choose({mode:"preset",value:"desktop"})
                var cancel=test.find(test.activeChooser,function(object){return object.objectName==="appearance-cancel"},[])
                if(!test.check(cancel && cancel.Accessible.role===Accessible.Button,"icon chooser exposes an accessible Cancel button"))return
                cancel.Accessible.pressAction()
                test.check(service.appearance.snapshot.bar_icon.value === "laptop", "chooser Cancel preserves state")
                test.phase=31
            } else if(test.phase === 31 && !service.appearance.busy) {
                test.check(service.appearance.setDeviceAppearance("A","Local phone",{mode:"preset",value:"desktop"}), "alias save starts")
                test.phase=4
            } else if(test.phase === 4 && !service.appearance.busy) {
                test.check(service.displayName(service.devices[0]) === "Local phone", "device alias uses own metadata")
                panel.settingsWindow.closeSettings()
                panel.open()
                test.click("Send")
                test.check(panel.currentView === "Send", "Send menu action")
                service.selectDevice("A")
                test.click("Choose files")
                test.check(service.selectionState === "choosing", "explicit portal choose starts")
                test.phase=5
            } else if(test.phase === 5 && service.selectionState === "draft") {
                test.check(service.selection.length === 2 && service.selectionBytes === 7, "portal files reach review with real sizes")
                test.capture("send")
                test.check(!service.operationBusy && service.operations.length === 0, "chooser close does not send")
                var draftBeforeNavigation = JSON.stringify(service.draftTarget) + JSON.stringify(service.selection)
                test.click("Activity")
                var navigation = test.find(panel,function(object) { return object.objectName === "daily-navigation" },[])
                test.check(navigation.draftSummary.indexOf("Draft for ") === 0, "draft review cue stays visible outside Send")
                test.click("Devices")
                test.click("Send")
                test.check(service.selectionState === "draft" && draftBeforeNavigation === JSON.stringify(service.draftTarget) + JSON.stringify(service.selection), "view changes preserve files and reviewed recipient")
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
                test.check(service.activeOperation.state === "request_accepted" && service.activeOperation.accepted === 2, "two sequential KDE requests accepted: " + service.activeOperation.state + "/" + service.activeOperation.error)
                test.check(service.activeOperation.delivery === "unknown", "accepted does not claim delivery")
                test.check(JSON.stringify(service.operations).indexOf("/one") === -1, "activity excludes raw file paths")
                test.click("Activity")
                test.check(panel.currentView === "Activity", "Activity menu action")
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
                test.check(panel.currentView === "Devices", "Devices menu action")
                service.openSyncthingPanel()
                test.phase=11
            } else if(test.phase === 11 && service.ownerPanelMessage.indexOf("unavailable") !== -1) {
                test.check(service.ownerPanelMessage.indexOf("Opened") === -1, "owner summon exit zero without confirmation stays unavailable")
                if (test.desktopMode) { test.capture("devices"); test.phase=12; test.ticks=0 }
                else test.stageIconDrop()
            } else if(test.phase === 12 && test.captures >= 2 && test.ticks > 20) {
                test.check(panel.opened, "actual native panel opened")
                test.stageIconDrop()
            } else if(test.phase === 13 && service.selectionState === "draft") {
                var review = test.find(widget,function(object) { return typeof object.openSend === "function" && "visible" in object },[])
                test.check(review && review.visible, "bar drop opens the persistent Send window")
                test.check(service.selection.length===1 && service.draftTarget.peerId==="A" && !service.operationBusy && service.operations.length===0, "bar drop preserves recipient and waits for explicit Send")
                service.cancelDraft()
                review.close()
                console.log("NATIVE_PASS "+JSON.stringify(test.outcomes))
                panel.close()
                Qt.quit()
            }
        }
    }
}
