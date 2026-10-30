import QtQuick
import QtQuick.Window
import Quickshell
import "plugin" as Plugin
import "plugin/components" as Components
import "plugin/ActionCatalog.js" as Actions

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int started: 0
    Plugin.Service { id: service }
    QtObject {
        id: fakeBar
        property color foreground: "#ffffff"
        property string fontFamily: "sans-serif"
    }
    QtObject {
        id: panel
        property var bar: fakeBar
        property var service: service
        property var device: service.selectedDevice
        property var availableActions: ["quick-share", "ping"]
        property bool cursorActive: false
        property string focusSection: ""
        property int actionSelectedIndex: -1
        property string activeComposer: ""
        property int dispatches: 0
        function triggerAction(id) { dispatches++ }
    }
    Window {
        visible: true
        width: 420
        height: 250
        Components.ActionToolbar { id: toolbar; panel: panel; width: parent.width }
    }
    function find(item, name) {
        if (item.objectName === name || ("modelData" in item && item.modelData === name)) return item
        for (var i = 0; i < item.children.length; ++i) {
            var found = find(item.children[i], name)
            if (found) return found
        }
        return null
    }
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL Quick Share: " + message); Qt.quit(); return false }
        return true
    }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (++test.ticks > 160) { test.check(false, "scenario finishes within deadline"); return }
            if (test.phase === 0 && service.appearance.ready && service.devices.length === 2 && service.quickShareAvailable) {
                service.selectDevice("A")
                if (!test.check(service.openQuickShare(), "fixed launcher starts")) return
                if (!test.check(service.pingDevice("A", "Fixture ping"), "device action can start while launcher runs")) return
                test.started = test.ticks
                test.phase = 1
            } else if (test.phase === 1 && test.ticks - test.started >= 15) {
                if (!test.check(service.actionState === "running" && service.actionMessage === "Requesting ping" && service.actionError === "", "launcher completion preserves the in-flight device action")) return
                if (!test.check(!service.quickShareOpening && !service.quickShareFailed && service.quickShareMessage.indexOf("RQuickShare launch requested") === 0, "successful launch has separate honest feedback")) return
                var status = test.find(toolbar, "quick-share-launch-status")
                if (!test.check(status && status.visible && status.text === service.quickShareMessage && status.textFormat === Text.PlainText && status.Accessible.name === status.text, "dedicated plain-text launch feedback is visible and accessible")) return
                test.phase = 2
            } else if (test.phase === 2 && service.actionState === "accepted") {
                service.actionState = "unknown"
                service.actionMessage = ""
                service.actionError = "Fixture device result is unconfirmed"
                if (!test.check(service.openQuickShare(), "launcher can start after the previous launch")) return
                test.phase = 3
            } else if (test.phase === 3) {
                if (!test.check(service.quickShareOpening && !service.quickShareFailed && service.quickShareMessage.indexOf("Opening RQuickShare") === 0, "launcher exposes its own pending state")) return
                if (!test.check(!service.openQuickShare() && !Actions.ready("quick-share", null, service), "duplicate launch is disabled and guarded")) return
                if (!test.check(Actions.availabilityText("quick-share", null, service).indexOf("Opening RQuickShare") === 0, "disabled shortcut explains its pending launch")) return
                var shortcut = test.find(toolbar, "quick-share")
                if (!test.check(shortcut && !shortcut.enabled && shortcut.Accessible.description.indexOf("Opening RQuickShare") !== -1, "native shortcut exposes its busy reason")) return
                shortcut.Accessible.pressAction()
                if (!test.check(panel.dispatches === 0, "disabled accessible press cannot dispatch a duplicate launch")) return
                test.phase = 4
            } else if (test.phase === 4 && !service.quickShareOpening) {
                if (!test.check(service.quickShareFailed && service.quickShareMessage.indexOf("RQuickShare could not open") === 0, "launcher failure has separate recovery feedback")) return
                if (!test.check(service.actionState === "unknown" && service.actionMessage === "" && service.actionError === "Fixture device result is unconfirmed", "launcher failure preserves an unknown device outcome")) return
                if (!test.check(!service.quickShareAvailable && !service.openQuickShare(), "unavailable launcher cannot run again")) return
                var failure = test.find(toolbar, "quick-share-launch-status")
                if (!test.check(failure.visible && failure.text === service.quickShareMessage && failure.text.indexOf("could not open") !== -1, "failure and recovery stay beside the shortcut")) return
                console.log("NATIVE_PASS Quick Share feedback isolation")
                Qt.quit()
            }
        }
    }
}
