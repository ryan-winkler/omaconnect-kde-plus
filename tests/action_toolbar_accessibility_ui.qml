import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "plugin/components" as Components
import "plugin/ActionCatalog.js" as Actions

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property bool failed: false
    property bool dispatching: false
    property var checks: []
    property var fileAction: null
    property var ringAction: null

    function check(value, message) {
        if (!value) {
            failed = true
            console.error("NATIVE_FAIL action toolbar: " + message)
            Qt.quit()
            return false
        }
        checks = checks.concat([message])
        return true
    }
    // Only traverse Item.children. Do not request Accessible on non-Item
    // objects from a general QObject/data traversal.
    function findAction(item, id) {
        if ("modelData" in item && item.modelData === id) return item
        for (var i = 0; i < item.children.length; i++) {
            var found = findAction(item.children[i], id)
            if (found) return found
        }
        return null
    }
    function semantics(item, id) {
        if (!check(!!item, id + " delegate exists")) return false
        var entry = Actions.entry(id)
        return check(item.Accessible.role === Accessible.Button, id + " exposes button role")
            && check(item.Accessible.name === entry.label, id + " exposes the visible action name")
            && check(item.Accessible.description === entry.description, id + " exposes contextual help")
            && check(item.activeFocusOnTab, id + " participates in ordinary Tab focus")
    }
    function key(code) {
        return check(events.keyClick(code, Qt.NoModifier, 1), "actual Qt key event delivered")
    }
    QtObject {
        id: fakeBar
        property color foreground: "#ffffff"
        property string fontFamily: "sans-serif"
    }
    QtObject {
        id: fakeService
        property bool fileBusy: false
        property string actionState: "idle"
    }
    QtObject {
        id: fakePanel
        property var bar: fakeBar
        property var service: fakeService
        property var device: ({id:"fixture",type:"phone",paired:true,reachable:true})
        property var availableActions: ["file", "ring"]
        property bool cursorActive: false
        property string focusSection: ""
        property int actionSelectedIndex: -1
        property string activeComposer: ""
        property var dispatches: []
        function triggerAction(id) { dispatches = dispatches.concat([id]) }
    }
    Window {
        id: preview
        visible: true
        width: 500
        height: 300
        Components.ActionToolbar { id: toolbar; panel: fakePanel; width: parent.width }
        Item { TestEvent { id: events } }
    }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (test.failed || test.dispatching) return
            test.dispatching = true
            try {
                if (++test.ticks > 160) { test.check(false, "scenario finishes within deadline"); return }
                if (test.phase === 0) {
                    test.fileAction = test.findAction(toolbar, "file")
                    test.ringAction = test.findAction(toolbar, "ring")
                    if (!test.semantics(test.fileAction, "file") || !test.semantics(test.ringAction, "ring")) return
                    preview.requestActivate()
                    test.fileAction.forceActiveFocus()
                    test.phase = 1
                } else if (test.phase === 1) {
                    if (!test.check(preview.activeFocusItem === test.fileAction, "file action receives native focus")) return
                    test.key(Qt.Key_Return)
                    test.phase = 2
                } else if (test.phase === 2) {
                    if (!test.check(fakePanel.dispatches.join(",") === "file", "Enter dispatches exactly one file action")) return
                    test.key(Qt.Key_Tab)
                    test.phase = 3
                } else if (test.phase === 3) {
                    if (!test.check(preview.activeFocusItem === test.ringAction, "Tab reaches the next daily action")) return
                    test.key(Qt.Key_Space)
                    test.phase = 4
                } else if (test.phase === 4) {
                    if (!test.check(fakePanel.dispatches.join(",") === "file,ring", "Space dispatches exactly one Ring action to the fake panel")) return
                    test.fileAction.Accessible.pressAction()
                    test.phase = 5
                } else if (test.phase === 5) {
                    if (!test.check(fakePanel.dispatches.join(",") === "file,ring,file", "accessible press uses the same action dispatch")) return
                    fakeService.fileBusy = true
                    fakeService.actionState = "running"
                    test.phase = 6
                } else if (test.phase === 6) {
                    if (!test.check(test.fileAction.enabled && !test.ringAction.enabled, "busy state retains Stop and disables another action")) return
                    if (!test.check(test.fileAction.Accessible.name === "Stop submitting", "busy file action exposes Stop name")) return
                    if (!test.check(test.fileAction.Accessible.description === "Cancel the current file submission", "busy file action exposes cancellation help")) return
                    test.ringAction.Accessible.pressAction()
                    if (!test.check(fakePanel.dispatches.join(",") === "file,ring,file", "accessible press cannot dispatch a disabled action")) return
                    test.fileAction.forceActiveFocus()
                    test.key(Qt.Key_Space)
                    test.phase = 7
                } else if (test.phase === 7) {
                    if (!test.check(fakePanel.dispatches.join(",") === "file,ring,file,file", "Space dispatches Stop once through the same fake boundary")) return
                    console.log("ACTION_TOOLBAR_ACCESSIBILITY_PASS " + JSON.stringify(test.checks))
                    console.log("NATIVE_PASS action toolbar accessibility")
                    Qt.quit()
                }
            } finally { test.dispatching = false }
        }
    }
}
