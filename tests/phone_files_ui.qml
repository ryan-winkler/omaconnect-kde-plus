import QtQuick
import QtQuick.Window
import Quickshell
import "plugin" as Plugin
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int started: 0
    Plugin.Service { id: service }
    QtObject {
        id: fakeBar
        property var shell: null
        property var activePopout: null
        property bool vertical: false
        property bool foregroundAnimationEnabled: false
        property int barSize: 26
        property string position: "top"
        property string fontFamily: "sans-serif"
        property color barForeground: "white"
        property color foreground: "white"
        property color urgent: "red"
        property int width: 1000
        property int height: 26
        function requestPopout(owner) { activePopout = owner }
        function releasePopout(owner) { if (activePopout === owner) activePopout = null }
        function hideTooltip(owner) {}
        function showTooltip(owner, text, options) {}
        function registerClickTarget(owner) {}
        function unregisterClickTarget(owner) {}
        function switchPanelFrom(owner, direction) { return false }
    }
    Window {
        visible: true
        width: 500
        height: 700
        Item { id: anchor; width: 26; height: 26 }
        Plugin.Panel { id: panel; bar: fakeBar; anchorItem: anchor; settings: ({showTailscale:false, showInlineSend:false}) }
        Components.PhoneFilesSection { id: files; width: 360; service: service }
    }
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL phone files: " + message); Qt.quit(); return false }
        return true
    }
    function find(object, name) {
        if (!object) return null
        if (object.objectName === name) return object
        var children = object.children || []
        for (var i=0;i<children.length;i++) { var found = find(children[i],name); if (found) return found }
        return null
    }
    function draftIntact() {
        return service.selectionState === "draft" && service.selection.length === 2 && service.draftTarget.peerId === "A"
    }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (++test.ticks > 500) { test.check(false,"deadline phase="+test.phase+" state="+service.phoneFilesState); return }
            if (test.phase === 0 && service.devices.length === 2 && service.appearance.ready) {
                service.selectDevice("A")
                if (!test.check(service.chooseFiles("A",{useDesktopFileChooser:true,reviewFilesBeforeSend:true}), "prepare independent Send draft")) return
                panel.open()
                test.phase = 1
            } else if (test.phase === 1 && service.selectionState === "draft") {
                panel.triggerAction("browse-files")
                if (!test.check(service.phoneFilesState === "preparing" && panel.dropActionRevealed && panel.inlineSendExpanded, "toolbar prepares and reveals existing File sharing section")) return
                if (!test.check(!service.browsePhoneFiles("A"), "duplicate prepare blocked")) return
                test.phase = 2
            } else if (test.phase === 2 && service.phoneFilesState === "opened") {
                if (!test.check(test.draftIntact(), "single root auto-opens without clearing Send draft")) return
                test.find(files,"browse-phone-files").clicked()
                test.phase = 3
            } else if (test.phase === 3 && service.phoneFilesState === "choosing") {
                if (!test.check(service.phoneFileLocations.length === 2 && !service.phoneFilesBusy, "multiple roots wait for choice")) return
                var choice = test.find(files,"phone-files-choice-1")
                if (!test.check(!!choice && choice.text === "<b>Second storage</b>" && choice.focusable && choice.height >= 44, "plain remote name and keyboard target")) return
                choice.clicked()
                if (!test.check(!service.openPhoneFileLocation(1), "duplicate open blocked")) return
                test.phase = 4
            } else if (test.phase === 4 && service.phoneFilesState === "opened") {
                service.browsePhoneFiles("A")
                test.started = test.ticks
                test.phase = 5
            } else if (test.phase === 5 && test.ticks-test.started > 4) {
                service.selectDevice("B")
                test.phase = 6
            } else if (test.phase === 6 && !service.phoneFilesBusy && test.ticks-test.started > 30) {
                if (!test.check(service.phoneFilesState === "idle" && service.phoneFileLocations.length === 0 && test.draftIntact(), "late old-peer prepare is ignored and draft target stays A")) return
                service.browsePhoneFiles("B")
                test.phase = 7
            } else if (test.phase === 7 && service.phoneFilesState === "failed") {
                if (!test.check(service.phoneFilesMessage.indexOf("default file manager") >= 0 && test.draftIntact(), "fixed opener failure preserves draft")) return
                service.browsePhoneFiles("B")
                test.phase = 8
            } else if (test.phase === 8 && service.phoneFilesState === "choosing") {
                test.find(files,"cancel-phone-files").clicked()
                if (!test.check(service.phoneFilesState === "cancelled" && service.phoneFileLocations.length === 0 && !service.openPhoneFileLocation(0), "cancel invalidates folder choices")) return
                service.browsePhoneFiles("B")
                test.started = test.ticks
                test.phase = 9
            } else if (test.phase === 9 && test.ticks-test.started > 4) {
                panel.close()
                test.phase = 10
            } else if (test.phase === 10 && !service.phoneFilesBusy && test.ticks-test.started > 30) {
                if (!test.check(service.phoneFilesState === "idle" && service.phoneFileLocations.length === 0 && test.draftIntact(), "popup close ignores late preparation")) return
                panel.open()
                service.browsePhoneFiles("B")
                test.phase = 11
            } else if (test.phase === 11 && service.phoneFilesState === "failed") {
                if (!test.check(service.phoneFileLocations.length === 0, "wrong-peer helper reply rejected")) return
                service.browsePhoneFiles("B")
                test.phase = 12
            } else if (test.phase === 12 && service.phoneFilesState === "failed" && !service.phoneFilesBusy) {
                if (!test.check(test.draftIntact(), "oversized helper reply preserves draft")) return
                console.log("NATIVE_PASS phone files")
                Qt.quit()
            }
        }
    }
}
