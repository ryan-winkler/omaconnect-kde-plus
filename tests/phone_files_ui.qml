import QtQuick
import QtQuick.Window
import Quickshell
import "plugin" as Plugin

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
        Plugin.Panel {
            id: panel
            bar: fakeBar
            anchorItem: anchor
            settings: ({showTailscale:false, showInlineSend:false, quickActionsOrder:"browse-files"})
        }
    }
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL phone files: " + message); Qt.quit(); return false }
        return true
    }
    function find(object, name, seen) {
        if (!object || seen.indexOf(object) !== -1) return null
        seen.push(object)
        if (object.objectName === name) return object
        for (var key of ["children", "data"]) {
            for (var child of object[key] || []) {
                var found = find(child, name, seen)
                if (found) return found
            }
        }
        for (var nested of ["contentItem", "item", "footer"]) {
            var result = find(object[nested], name, seen)
            if (result) return result
        }
        return null
    }
    function named(name) { return find(panel, name, []) }
    function browseAction() { return named("quick-action-browse-files") }
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
                var browse = test.browseAction()
                if (!test.check(browse && browse.visible && browse.enabled, "real Browse toolbar button is reachable")) return
                browse.clicked()
                if (!test.check(service.phoneFilesState === "preparing" && !panel.sectionVisible("drop") && !panel.inlineSendExpanded, "toolbar prepares without opening File sharing")) return
                if (!test.check(browse.enabled && browse.Accessible.name === "Cancel browse", "pending toolbar cancellation is accessible")) return
                if (!test.check(!service.browsePhoneFiles("A"), "duplicate prepare blocked")) return
                test.phase = 2
            } else if (test.phase === 2 && service.phoneFilesState === "opened") {
                if (!test.check(test.draftIntact() && !panel.inlineSendExpanded && !panel.sectionVisible("drop"), "single root auto-opens with File sharing collapsed and the Send draft intact")) return
                test.browseAction().clicked()
                test.phase = 3
            } else if (test.phase === 3 && service.phoneFilesState === "choosing") {
                if (!test.check(service.phoneFileLocations.length === 2 && !service.phoneFilesBusy && panel.sectionBodyVisible("drop"), "multiple roots reveal File sharing and wait for choice")) return
                if (!test.check(test.browseAction().Accessible.name === "Cancel browse" && !test.named("browse-phone-files").visible && !test.named("cancel-phone-files").visible && !service.browsePhoneFiles("A"), "one cancel action and no competing Browse during choice")) return
                var choice = test.named("phone-files-choice-1")
                if (!test.check(!!choice && choice.text === "<b>Second storage</b>" && choice.focusable && choice.height >= 44, "plain remote name and keyboard target")) return
                choice.clicked()
                if (!test.check(!service.openPhoneFileLocation(1), "duplicate open blocked")) return
                test.phase = 4
            } else if (test.phase === 4 && service.phoneFilesState === "opened") {
                panel.settings = Object.assign({}, panel.settings, {showInlineSend:true})
                if (!test.check(!test.named("browse-phone-files").visible, "inline Browse is hidden while toolbar Browse is available")) return
                panel.settings = Object.assign({}, panel.settings, {quickActionsOrder:""})
                var inlineBrowse = test.named("browse-phone-files")
                if (!test.check(inlineBrowse.visible && inlineBrowse.enabled, "inline Browse returns when the shortcut is removed")) return
                inlineBrowse.clicked()
                if (!test.check(test.named("cancel-phone-files").visible, "inline Browse keeps its own cancel when the shortcut is removed")) return
                test.started = test.ticks
                test.phase = 5
            } else if (test.phase === 5 && test.ticks-test.started > 4) {
                service.selectDevice("B")
                test.phase = 6
            } else if (test.phase === 6 && !service.phoneFilesBusy && test.ticks-test.started > 30) {
                if (!test.check(service.phoneFilesState === "idle" && service.phoneFileLocations.length === 0 && test.draftIntact(), "late old-peer prepare is ignored and draft target stays A")) return
                panel.settings = Object.assign({}, panel.settings, {showInlineSend:false,quickActionsOrder:"browse-files"})
                panel.setSectionExpanded("drop", false)
                test.browseAction().clicked()
                test.phase = 7
            } else if (test.phase === 7 && service.phoneFilesState === "failed") {
                if (!test.check(service.phoneFilesMessage.indexOf("default file manager") >= 0 && test.draftIntact() && panel.sectionBodyVisible("drop"), "opener failure reveals recovery and preserves draft")) return
                test.browseAction().clicked()
                test.phase = 8
            } else if (test.phase === 8 && service.phoneFilesState === "choosing") {
                test.browseAction().clicked()
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
                panel.setSectionExpanded("drop", false)
                test.browseAction().clicked()
                test.started = test.ticks
                test.phase = 13
            } else if (test.phase === 13 && test.ticks-test.started > 4) {
                if (!test.check(service.phoneFilesState === "preparing" && !panel.inlineSendExpanded, "pending quick Browse keeps File sharing collapsed")) return
                panel.setSectionExpanded("actions", false)
                if (!test.check(panel.sectionBodyVisible("drop") && test.named("cancel-phone-files").visible, "collapsing Quick actions reveals inline cancellation")) return
                panel.setSectionExpanded("actions", true)
                if (!test.check(!test.named("cancel-phone-files").visible, "only toolbar cancellation remains visible")) return
                test.browseAction().clicked()
                if (!test.check(service.phoneFilesState === "cancelled" && test.draftIntact(), "pending cancellation preserves the draft")) return
                test.phase = 14
            } else if (test.phase === 14 && !service.phoneFilesBusy) {
                test.browseAction().clicked()
                test.phase = 15
            } else if (test.phase === 15 && service.phoneFilesState === "failed" && !service.phoneFilesBusy) {
                var status = test.named("phone-files-status")
                var settings = test.named("phone-files-native-settings")
                if (!test.check(status.visible && status.text.indexOf("unmounted") >= 0
                    && status.Accessible.name === status.text && test.browseAction().enabled && settings.enabled
                    && test.draftIntact(), "unmounted response offers accessible manual recovery")) return
                console.log("NATIVE_PASS phone files")
                Qt.quit()
            }
        }
    }
}
