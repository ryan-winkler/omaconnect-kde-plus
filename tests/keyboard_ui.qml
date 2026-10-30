import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "plugin" as Plugin

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int attempts: 0
    property bool failed: false
    property bool dispatching: false
    property var outcomes: []
    property var textTarget: null
    property string selectedBeforeTyping: ""
    property int indexBeforeTyping: -1
    property bool cursorBeforeTyping: false
    property string pairingBeforeTyping: ""
    readonly property string typedText: "hjklpruyx"

    function check(value, message) {
        if (!value) {
            failed = true
            console.error("NATIVE_FAIL keyboard: " + message + " phase=" + phase + " focus=" + focusLabel())
            Qt.quit()
            return false
        }
        outcomes = outcomes.concat([message])
        return true
    }
    function find(object, predicate, seen) {
        if (!object || seen.indexOf(object) !== -1) return null
        seen.push(object)
        if (predicate(object)) return object
        var lists = ["children", "data"]
        for (var i = 0; i < lists.length; i++) {
            var list = object[lists[i]]
            if (!list || typeof list.length !== "number") continue
            for (var j = 0; j < list.length; j++) {
                var found = find(list[j], predicate, seen)
                if (found) return found
            }
        }
        var single = ["contentItem", "item"]
        for (var k = 0; k < single.length; k++) {
            var child = object[single[k]]
            if (child) {
                var result = find(child, predicate, seen)
                if (result) return result
            }
        }
        return null
    }
    function isWithin(object, ancestor) {
        while (object) {
            if (object === ancestor) return true
            object = object.parent
        }
        return false
    }
    function named(label) {
        return find(panel, function(object) {
            return "text" in object && object.text === label && typeof object.clicked === "function"
        }, [])
    }
    function focusLabel() {
        var item = preview.activeFocusItem
        return item ? String(item) + ":" + (item.text || item.placeholderText || item.objectName || "") : "none"
    }
    function key(code, modifiers) {
        return events.keyClick(code, modifiers || Qt.NoModifier, 1) || check(false, "Qt key event delivered")
    }
    function seek(target) {
        if (!target) { check(false, "keyboard target exists"); return false }
        if (isWithin(preview.activeFocusItem, target)) { attempts = 0; return true }
        if (++attempts > 80) { check(false, "Tab reaches " + (target.text || target.placeholderText || String(target))); return false }
        key(Qt.Key_Tab)
        return false
    }
    function rememberTyping(target) {
        textTarget = target
        selectedBeforeTyping = service.selectedDeviceId
        indexBeforeTyping = panel.selectedIndex
        cursorBeforeTyping = panel.cursorActive
        pairingBeforeTyping = JSON.stringify(service.pendingPairing)
        for (var i = 0; i < typedText.length; i++)
            if (!events.keyClickChar(typedText[i], Qt.NoModifier, 1)) check(false, "Qt text event delivered")
    }
    function verifyTyping(label) {
        check(textTarget.text === typedText, label + " accepts hjkl and action letters")
        check(service.selectedDeviceId === selectedBeforeTyping && panel.selectedIndex === indexBeforeTyping,
              label + " does not navigate devices")
        check(panel.cursorActive === cursorBeforeTyping && JSON.stringify(service.pendingPairing) === pairingBeforeTyping,
              label + " does not trigger panel shortcuts")
    }

    Plugin.Service { id: service }
    QtObject { id: facade; function serviceFor(id) { return null } }
    QtObject {
        id: fakeBar
        property var shell: facade
        property color barForeground: "#ffffff"
        property color foreground: "#ffffff"
        property string fontFamily: "sans-serif"
        property int switches: 0
        function switchPanelFrom(owner, direction) { switches++; return false }
    }
    Window {
        id: preview
        // An offscreen QWindow is required for actual Qt keyboard dispatch.
        // The Python harness always forces QT_QPA_PLATFORM=offscreen here.
        visible: true
        width: 500
        height: 900
        Item { id: anchor; width: 26; height: 26 }
        Plugin.Panel { id: panel; bar: fakeBar; anchorItem: anchor; settings: ({showSyncthingLinks:true,showTailscale:false, networkTailscaleEnabled:true, networkBthEnabled:true, networkWireguardEnabled:true}) }
        Item { TestEvent { id: events } }
    }
    Timer {
        interval: 20
        running: true
        repeat: true
        onTriggered: {
            if (test.failed || test.dispatching) return
            // QTest key delivery can process the event loop. Do not let this
            // timer re-enter the same step and inject a second key meanwhile.
            test.dispatching = true
            try {
            if (++test.ticks > 600) { test.check(false, "bounded keyboard scenario finishes"); return }
            if (test.phase === 0 && service.appearance.ready && service.devices.length === 2) {
                panel.open()
                preview.requestActivate()
                panel.focusTarget.forceActiveFocus()
                test.phase = 1
            } else if (test.phase === 1) {
                if (!test.check(preview.activeFocusItem === panel.focusTarget, "initial device catcher has focus")) return
                test.key(Qt.Key_Tab)
                test.phase = 2
            } else if (test.phase === 2) {
                var trigger = test.find(panel, function(object) { return object.objectName === "daily-view-menu" }, [])
                if (!test.check(!!trigger && test.isWithin(preview.activeFocusItem, trigger), "Tab enters the labelled view menu from device catcher")) return
                test.check(fakeBar.switches === 0, "Tab stays inside this panel")
                test.key(Qt.Key_Space)
                test.phase = 3
            } else if (test.phase === 3) {
                test.key(Qt.Key_Down)
                test.key(Qt.Key_Return)
                test.phase = 4
            } else if (test.phase === 4) {
                if (!test.check(panel.currentView === "Send", "keyboard activates Send view")) return
                test.key(Qt.Key_Space)
                test.phase = 41
            } else if (test.phase === 41) {
                test.key(Qt.Key_Down)
                test.key(Qt.Key_Return)
                test.phase = 42
            } else if (test.phase === 42) {
                if (!test.check(panel.currentView === "Activity", "keyboard activates Activity view")) return
                test.key(Qt.Key_Space)
                test.phase = 5
            } else if (test.phase === 5) {
                test.key(Qt.Key_Up)
                test.key(Qt.Key_Up)
                test.key(Qt.Key_Return)
                test.phase = 11
            } else if (test.phase === 11) {
                if (!test.check(panel.currentView === "Devices", "keyboard returns to Devices")) return
                test.phase = 12
            } else if (test.phase === 12) {
                if (!test.check(preview.activeFocusItem === panel.focusTarget, "choosing Devices returns to device navigation")) return
                test.key(Qt.Key_Down)
                test.phase = 13
            } else if (test.phase === 13) {
                test.key(Qt.Key_Down)
                test.phase = 14
            } else if (test.phase === 14) {
                if (!test.check(panel.cursorActive && panel.selectedIndex === 1, "device arrow navigation remains available")) return
                test.key(Qt.Key_Tab)
                test.phase = 141
            } else if (test.phase === 141 && test.seek(test.find(panel,function(object) { return object.objectName === "device-settings-B" },[]))) {
                test.key(Qt.Key_Return)
                test.phase = 142
            } else if (test.phase === 142) {
                if (!test.check(panel.settingsWindow.visible && panel.settingsWindow.currentPage === "Device features" && service.selectedDeviceId === "B", "keyboard gear opens Plus settings for the exact paired device")) return
                if (!test.check(!service.nativeAppOpening, "keyboard gear keeps native launch explicit")) return
                panel.settingsWindow.closeSettings()
                panel.open()
                preview.requestActivate()
                panel.focusTarget.forceActiveFocus()
                test.phase = 15
            } else if (test.phase === 15 && test.seek(test.named("Native KDE Connect settings"))) {
                test.check(true, "Tab reaches all native KDE features")
                test.phase = 153
            } else if (test.phase === 153 && test.seek(test.named("Open Tailscale panel"))) {
                test.check(true, "Tab reaches native Tailscale owner route without launching")
                test.phase = 154
            } else if (test.phase === 154 && test.seek(test.named("Open WireGuard profiles"))) {
                test.check(true, "Tab reaches native WireGuard owner route without launching")
                test.phase = 155
            } else if (test.phase === 155 && test.seek(test.named("Automatic"))) {
                test.check(test.named("Automatic").enabled, "safe fake BTH controls are enabled")
                test.check(true, "Tab reaches BTH Automatic")
                test.key(Qt.Key_Tab)
                test.phase = 16
            } else if (test.phase === 16) {
                if (!test.check(test.isWithin(preview.activeFocusItem, test.named("On")), "Tab reaches BTH On")) return
                test.key(Qt.Key_Tab)
                test.phase = 17
            } else if (test.phase === 17) {
                if (!test.check(test.isWithin(preview.activeFocusItem, test.named("Off")), "Tab reaches BTH Off")) return
                test.phase = 18
            } else if (test.phase === 18 && test.seek(test.named("Manage saved addresses"))) {
                test.key(Qt.Key_Return)
                test.phase = 19
            } else if (test.phase === 19) {
                if (!test.check(panel.addressesExpanded, "keyboard expands saved-address controls")) return
                test.phase = 20
            } else if (test.phase === 20) {
                var address = test.find(panel, function(object) { return "placeholderText" in object && object.placeholderText === "Private or Tailscale IP address" }, [])
                if (test.seek(address)) { test.rememberTyping(address); test.phase = 21 }
            } else if (test.phase === 21) {
                test.verifyTyping("Private address editor")
                test.key(Qt.Key_Backtab, Qt.ShiftModifier)
                test.phase = 22
            } else if (test.phase === 22) {
                test.check(test.isWithin(preview.activeFocusItem, test.named("Hide saved addresses")), "Shift+Tab returns to address disclosure")
                test.phase = 23
            } else if (test.phase === 23 && test.seek(test.named("Syncthing identity note"))) {
                test.key(Qt.Key_Return)
                test.phase = 24
            } else if (test.phase === 24) {
                if (!test.check(panel.syncthingExpanded, "keyboard expands Syncthing link controls")) return
                test.phase = 25
            } else if (test.phase === 25) {
                var syncthing = test.find(panel, function(object) { return "placeholderText" in object && object.placeholderText === "Full Syncthing device ID" }, [])
                if (test.seek(syncthing)) { test.rememberTyping(syncthing); test.phase = 26 }
            } else if (test.phase === 26) {
                test.verifyTyping("Syncthing ID editor")
                test.key(Qt.Key_Backtab, Qt.ShiftModifier)
                test.phase = 27
            } else if (test.phase === 27) {
                test.check(preview.activeFocusItem !== test.textTarget, "Shift+Tab leaves the Syncthing editor")
                test.check(panel.opened && panel.currentView === "Devices", "typing leaves the panel open in its view")
                test.check(fakeBar.switches === 0, "keyboard traversal never switches another bar panel")
                if (test.failed) return
                service.discoveryState = "not_installed"
                service.devices = []
                test.phase = 28
            } else if (test.phase === 28) {
                var install = test.find(panel, function(object) { return object.objectName === "kdeconnect-install-command" }, [])
                if (test.seek(install)) {
                    if (!test.check(install.readOnly && install.selectedText === install.text, "install command selects all on keyboard focus")) return
                    test.selectedBeforeTyping = service.selectedDeviceId
                    test.indexBeforeTyping = panel.selectedIndex
                    test.key(Qt.Key_Left)
                    test.key(Qt.Key_A, Qt.ControlModifier)
                    if (!test.check(install.selectedText === install.text && panel.selectedIndex === test.indexBeforeTyping && service.selectedDeviceId === test.selectedBeforeTyping, "install command selection keys do not navigate devices")) return
                    test.phase = 29
                }
            } else if (test.phase === 29) {
                console.log("KEYBOARD_PASS " + JSON.stringify(test.outcomes))
                console.log("NATIVE_PASS keyboard")
                Qt.quit()
            }
            } finally { test.dispatching = false }
        }
    }
}
