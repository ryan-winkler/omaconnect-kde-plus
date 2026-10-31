import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "plugin" as Plugin
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property var heldUp: null
    property var heldDown: null
    property var heldRow: null
    property var heldToggle: null
    readonly property var catalogueForPanel: catalog
    Plugin.PanelSectionCatalog { id: catalog; storedOrder: fakePanel.getSetting("sectionOrder", "") }
    FileView { id: gate; path: Qt.resolvedUrl("save-gate").toString().replace(/^file:\/\//, ""); preload: true; blockWrites: true }
    FileView { id: requestState; path: Qt.resolvedUrl("request-started").toString().replace(/^file:\/\//, ""); preload: true; watchChanges: true; onFileChanged: reload() }
    QtObject {
        id: fakePanel
        property var settings: ({sectionOrder: "", networkBthEnabled: true, showSyncthingLinks: false})
        property var sectionCatalog: test.catalogueForPanel
        function getSetting(key, fallback) { return key in settings ? settings[key] : fallback }
    }
    Window {
        id: window
        visible: true
        width: 520
        height: 780
        Column {
            width: parent.width
            Components.SectionOrderSettings { id: editor; panel: fakePanel; width: parent.width }
            Components.PreferenceControls { id: booleanSaver; panel: fakePanel; width: parent.width; preferences: [{key:"showRemoteCommands",label:"Fixture command visibility",defaultValue:true}] }
        }
    }
    TestCase { id: events; when: false }
    function find(item, name) {
        if (item.objectName === name || item.Accessible.name === name) return item
        for (var i = 0; i < item.children.length; ++i) {
            var found = find(item.children[i], name)
            if (found) return found
        }
        return null
    }
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL section order: " + message); Qt.quit(); return false }
        console.log("SECTION_ORDER_PASS " + message)
        return true
    }
    Timer {
        interval: 30
        running: true
        repeat: true
        onTriggered: {
            if (++test.ticks > 160) { test.check(false, "bounded scenario"); return }
            if (test.phase === 0 && catalog.ready) {
                if (!test.check(catalog.entries.length === 9 && catalog.order.length === 9, "one fixed catalogue supplies all nine rows")) return
                if (!test.check(catalog.preferencesFor("Connections").length === 6, "domain visibility and expansion preferences share metadata")) return
                if (!test.check(!test.find(editor, "Move Devices up").enabled && !test.find(editor, "Move Syncthing identity note down").enabled, "endpoints cannot move beyond the catalogue")) return
                test.heldUp = test.find(editor, "Move Quick actions up")
                test.heldDown = test.find(editor, "Move Quick actions down")
                test.heldRow = test.find(editor, "section-order-row-actions")
                window.requestActivate();test.heldUp.forceActiveFocus();test.phase = 10
            } else if (test.phase === 10) {
                if (!test.check(window.activeFocusItem === test.heldUp, "native Up button receives keyboard focus")) return
                events.keyClick(Qt.Key_Space, Qt.NoModifier, 1);test.phase = 11
            } else if (test.phase === 11) {
                if (requestState.text() !== "sectionOrder") return
                if (!test.check(editor.busy && test.heldUp.enabled && window.activeFocusItem === test.heldUp, "held save preserves focus on the enabled Up button; enabled="+test.heldUp.enabled+" focused="+(window.activeFocusItem===test.heldUp)+" actual="+(window.activeFocusItem?window.activeFocusItem.objectName:"none"))) return
                if (!test.check(catalog.order[0] === "devices", "request does not optimistically change saved order")) return
                events.keyClick(Qt.Key_Space, Qt.NoModifier, 1)
                if (!test.check(editor.message.indexOf("not submitted") >= 0, "repeated busy activation explicitly reports not submitted")) return
                test.find(editor, "Use default section order").Accessible.pressAction()
                gate.setText("release");test.phase = 1
            } else if (test.phase === 1 && !editor.busy && editor.message === "Setting saved.") {
                if (!test.check(catalog.order[0] === "devices", "successful request still waits for configuration readback")) return
                fakePanel.settings = ({sectionOrder: "actions,devices,drop,native,media,commands,connections,addresses,syncthing", networkBthEnabled: true, showSyncthingLinks: false})
                test.phase = 2
            } else if (test.phase === 2 && catalog.order[0] === "actions") {
                if (!test.check(test.find(editor,"section-order-row-actions") === test.heldRow && test.find(editor,"Move Quick actions up") === test.heldUp, "readback moves the original row and controls without recreation")) return
                if (!test.check(!test.heldUp.enabled && test.heldDown.enabled && window.activeFocusItem === test.heldDown, "first-row boundary moves focus to the enabled same-row neighbor")) return
                events.keyClick(Qt.Key_Tab, Qt.NoModifier, 1);test.phase=20
            } else if (test.phase === 20) {
                if (!test.check(window.activeFocusItem === test.find(editor,"Move Devices up"), "ordinary Tab follows the moved visual row order")) return
                events.keyClick(Qt.Key_Tab, Qt.ShiftModifier, 1);test.phase=21
            } else if (test.phase === 21) {
                if (!test.check(window.activeFocusItem === test.heldDown, "Shift Tab returns to the moved row")) return
                test.find(editor, "Move Syncthing identity note up").Accessible.pressAction();test.phase = 3
            } else if (test.phase === 3 && !editor.busy && editor.message.indexOf("not confirmed") >= 0) {
                if (!test.check(catalog.order[0] === "actions" && catalog.order[8] === "syncthing", "failed save preserves the read-back order")) return
                test.find(editor, "Use default section order").forceActiveFocus()
                events.keyClick(Qt.Key_Space, Qt.NoModifier, 1);test.phase = 4
            } else if (test.phase === 4 && !editor.busy && editor.message === "Setting saved.") {
                fakePanel.settings = ({sectionOrder: "", networkBthEnabled: true, showSyncthingLinks: false})
                test.phase = 5
            } else if (test.phase === 5 && catalog.order[0] === "devices") {
                if (!test.check(fakePanel.settings.networkBthEnabled && fakePanel.settings.showSyncthingLinks === false, "Reset changes order only, preserving provider and visibility choices")) return
                gate.setText("hold")
                test.heldToggle = test.find(booleanSaver,"preference-showRemoteCommands")
                test.heldToggle.forceActiveFocus();test.phase=6
            } else if (test.phase === 6) {
                if (!test.check(window.activeFocusItem === test.heldToggle, "boolean control receives keyboard focus")) return
                events.keyClick(Qt.Key_Space, Qt.NoModifier, 1);test.phase=7
            } else if (test.phase === 7) {
                if (requestState.text() !== "showRemoteCommands") return
                if (!test.check(booleanSaver.busy && test.heldToggle.enabled && window.activeFocusItem === test.heldToggle && test.heldToggle.checked, "held boolean save retains focus and authoritative checked state; enabled="+test.heldToggle.enabled+" focused="+(window.activeFocusItem===test.heldToggle))) return
                events.keyClick(Qt.Key_Space, Qt.NoModifier, 1)
                if (!test.check(booleanSaver.message.indexOf("not submitted") >= 0, "busy boolean repeat is rejected without a queue")) return
                gate.setText("release");test.phase=8
            } else if (test.phase === 8 && !booleanSaver.busy && booleanSaver.message === "Setting saved.") {
                if (!test.check(test.heldToggle.checked, "boolean ACK alone does not fabricate readback")) return
                fakePanel.settings = ({sectionOrder:"",networkBthEnabled:true,showSyncthingLinks:false,showRemoteCommands:false});test.phase=9
            } else if (test.phase === 9) {
                if (!test.check(!test.heldToggle.checked && window.activeFocusItem === test.heldToggle, "boolean readback changes value without stealing focus")) return
                console.log("NATIVE_PASS section order")
                Qt.quit()
            }
        }
    }
}
