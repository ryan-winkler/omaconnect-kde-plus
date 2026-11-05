import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int backs: 0
    property int secondaryBacks: 0
    property int cancels: 0
    property var confirmations: []
    property bool acceptConfirmation: false
    property int primaryOwnerGeneration: 1
    property int secondaryOwnerGeneration: 0
    property var secondaryConfirmations: []
    property var checks: []
    function check(value, label) {
        if (!value) { console.error("NATIVE_FAIL image preview: " + label); Qt.quit(); return false }
        checks = checks.concat([label]); return true
    }
    function find(object, name) {
        if (!object) return null
        if (object.objectName === name) return object
        var children = object.children || []
        for (var i = 0; i < children.length; i++) {
            var found = find(children[i], name)
            if (found) return found
        }
        return null
    }
    TestCase { id: keyboard; name: "ScopedPreviewKeyboard"; when: false }
    Process {
        id: languageWriter
        command: ["python3", "-c", "import os,pathlib; pathlib.Path(os.environ['XDG_CONFIG_HOME'],'omarchy','language').write_text('ar'+chr(10))"]
    }
    QtObject {
        id: state
        property string selectionState: "idle"
        property var previewCandidates: ["FIXTURE_PATH/preview-one.png", "FIXTURE_PATH/preview-second #?.png"]
        property bool previewSubmits: true
        property var draftTarget: ({peerId: "captured", peerName: "<b>Captured phone</b>"})
        property string selectionError: ""
        property string selectedDeviceId: "another-phone"
        property int selectionGeneration: 1
    }
    Components.ImagePreviewWindow {
        id: preview
        service: state
        activeForOwner: state.selectionGeneration === test.primaryOwnerGeneration
        onBackRequested: { test.backs++; state.selectionState = "choosing" }
        onCancelRequested: { test.cancels++; state.selectionState = "idle" }
        onConfirmRequested: function(path) {
            test.confirmations = test.confirmations.concat([path])
            if (test.acceptConfirmation) state.selectionState = "draft"
        }
    }
    Components.ImagePreviewWindow {
        id: secondaryPreview
        service: state
        activeForOwner: state.selectionGeneration === test.secondaryOwnerGeneration
        onBackRequested: { test.secondaryBacks++; state.selectionState = "choosing" }
        onCancelRequested: { test.cancels++; state.selectionState = "idle" }
        onConfirmRequested: function(path) {
            test.secondaryConfirmations = test.secondaryConfirmations.concat([path])
            state.selectionState = "draft"
        }
    }
    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (++test.ticks > 150) { test.check(false, "scenario completes"); return }
            var image = test.find(preview.contentItem, "image-preview-image")
            var search = test.find(preview.contentItem, "image-preview-search")
            var primary = test.find(preview.contentItem, "image-preview-confirm")
            var back = test.find(preview.contentItem, "image-preview-back")
            var cancel = test.find(preview.contentItem, "image-preview-cancel")
            if (test.phase === 0) {
                if (!test.check(!preview.visible && String(image.source) === "", "inactive preview decodes no image")) return
                state.selectionState = "preview"; test.phase++
            } else if (test.phase === 1 && preview.visible && image.status === Image.Ready) {
                var recipient = test.find(preview.contentItem, "image-preview-recipient")
                if (!test.check(recipient.textFormat === Text.PlainText && recipient.text.indexOf("<b>Captured phone</b>") !== -1,
                    "captured recipient is shown as plain text")) return
                if (!test.check(search.activeFocus && !primary.activeFocus, "initial focus is search, not Send")) return
                if (!test.check(image.asynchronous && !image.cache && image.fillMode === Image.PreserveAspectFit
                    && image.sourceSize.width <= 1600 && image.sourceSize.height <= 1200,
                    "one bounded asynchronous image preserves aspect ratio without cache")) return
                test.find(preview.contentItem, "image-preview-next").clicked()
                test.phase++
            } else if (test.phase === 2 && image.status === Image.Ready && preview.selectedIndex === 1) {
                if (!test.check(primary.enabled && String(image.source).indexOf("%23%3F") !== -1,
                    "special filename characters remain local URL data")) return
                if (!test.check(test.confirmations.length === 0, "Next never sends")) return
                search.text = "missing"; test.phase++
            } else if (test.phase === 3) {
                if (!test.check(!primary.enabled && back.enabled && cancel.enabled && String(image.source) === "",
                    "empty search disables Send while Back and Cancel remain available")) return
                search.text = "preview-one"; test.phase++
            } else if (test.phase === 4 && image.status === Image.Ready && primary.enabled) {
                if (!test.check(test.confirmations.length === 0, "search never sends")) return
                primary.clicked(); state.selectionError = "Phone is offline. Try again."; test.phase++
            } else if (test.phase === 5) {
                var error = test.find(preview.contentItem, "image-preview-error")
                if (!test.check(test.confirmations.length === 1 && test.confirmations[0] === state.previewCandidates[0]
                    && preview.visible && error.visible && error.textFormat === Text.PlainText,
                    "explicit confirmation keeps a rejected request and error visible")) return
                preview.close(); test.phase++
            } else if (test.phase === 6 && !preview.visible) {
                if (!test.check(test.cancels === 1 && String(image.source) === "", "WM Close cancels only this request and clears image source")) return
                state.selectionError = ""; state.previewSubmits = false; state.selectionState = "preview"; test.phase++
            } else if (test.phase === 7 && preview.visible && image.status === Image.Ready && primary.enabled) {
                if (!test.check(primary.text === "Review image", "captured review policy names the next step")) return
                test.acceptConfirmation = true; primary.clicked(); test.phase++
            } else if (test.phase === 8 && !preview.visible) {
                if (!test.check(test.confirmations.length === 2 && test.cancels === 1, "successful handoff hides without cancellation")) return
                preview.close(); state.selectionState = "preview"; test.phase++
            } else if (test.phase === 9 && preview.visible) {
                if (!test.check(test.cancels === 1, "close while inactive preserves the visibility binding")) return
                back.clicked(); test.phase++
            } else if (test.phase === 10 && !preview.visible) {
                if (!test.check(test.backs === 1 && test.cancels === 1 && test.confirmations.length === 2,
                    "Back returns to file choice without sending or cancelling")) return
                state.previewCandidates = ["FIXTURE_PATH/unavailable-image.png"]
                state.selectionState = "preview"; test.phase++
            } else if (test.phase === 11 && image.status === Image.Error) {
                var status = test.find(preview.contentItem, "image-preview-status")
                if (!test.check(!primary.enabled && back.enabled && cancel.enabled
                    && status.text.indexOf("cannot be previewed") !== -1,
                    "unavailable image disables Send and explains the Back fallback")) return
                cancel.clicked(); test.phase++
            } else if (test.phase === 12 && !preview.visible) {
                if (!test.check(test.cancels === 2 && test.confirmations.length === 2 && String(image.source) === "",
                    "Cancel never sends and releases the current decode")) return
                state.previewCandidates = ["FIXTURE_PATH/preview-one.png", "FIXTURE_PATH/preview-second #?.png"]
                state.previewSubmits = true; state.selectionState = "preview"; test.phase++
            } else if (test.phase === 13 && preview.visible && image.status === Image.Ready && primary.enabled) {
                if (!test.check(search.activeFocus, "keyboard scenario starts in Search")) return
                keyboard.keyClick(Qt.Key_Return)
                if (!test.check(test.confirmations.length === 2, "Return in Search does not send")) return
                keyboard.keyClick(Qt.Key_Tab)
                if (!test.check(test.find(preview.contentItem,"image-preview-next").activeFocus && !primary.activeFocus,
                    "actual Tab reaches Next rather than Send")) return
                keyboard.keyClick(Qt.Key_Backtab)
                if (!test.check(search.activeFocus, "actual Shift Tab returns to Search")) return
                image.parent.forceActiveFocus()
                keyboard.keyClick(Qt.Key_Right)
                if (!test.check(preview.selectedIndex === 1 && test.confirmations.length === 2,
                    "actual Right key browses without sending")) return
                test.phase++
            } else if (test.phase === 14 && image.status === Image.Ready) {
                image.parent.forceActiveFocus()
                keyboard.keyClick(Qt.Key_Left)
                if (!test.check(preview.selectedIndex === 0 && test.confirmations.length === 2,
                    "actual Left key browses without sending")) return
                keyboard.keyClick(Qt.Key_Left, Qt.AltModifier)
                test.phase++
            } else if (test.phase === 15 && !preview.visible) {
                if (!test.check(test.backs === 2 && test.cancels === 2,
                    "actual Alt Left returns to files without cancellation")) return
                state.selectionState = "preview"; test.phase++
            } else if (test.phase === 16 && preview.visible && image.status === Image.Ready && primary.enabled) {
                keyboard.keyClick(Qt.Key_Escape)
                test.phase++
            } else if (test.phase === 17 && !preview.visible) {
                if (!test.check(test.cancels === 3 && test.confirmations.length === 2,
                    "actual Escape cancels the focused preview")) return
                state.selectionState = "preview"; test.phase++
            } else if (test.phase === 18 && preview.visible && image.status === Image.Ready && primary.enabled) {
                primary.forceActiveFocus()
                keyboard.keyClick(Qt.Key_Space)
                test.phase++
            } else if (test.phase === 19 && !preview.visible) {
                if (!test.check(test.confirmations.length === 3 && test.cancels === 3,
                    "actual Space activates only the deliberately focused primary action")) return
                state.selectionState = "preview"; test.phase++
            } else if (test.phase === 20 && preview.visible && image.status === Image.Ready) {
                var secondaryImage = test.find(secondaryPreview.contentItem, "image-preview-image")
                if (!test.check(!secondaryPreview.visible && !secondaryPreview.canConfirm && String(secondaryImage.source) === "",
                    "only the matching owner view opens and decodes")) return
                state.selectionGeneration++
                test.secondaryOwnerGeneration = state.selectionGeneration
                test.phase++
            } else if (test.phase === 21 && secondaryPreview.visible) {
                var secondaryImage = test.find(secondaryPreview.contentItem, "image-preview-image")
                if (secondaryImage.status !== Image.Ready) return
                if (!test.check(!preview.visible && !preview.canConfirm && String(image.source) === "",
                    "new selection generation revokes the old view and releases its decode")) return
                preview.confirm(); primary.clicked(); preview.close()
                back.clicked(); cancel.clicked()
                if (!test.check(test.confirmations.length === 3 && test.backs === 2 && test.cancels === 3
                    && !back.enabled && !cancel.enabled && secondaryPreview.visible,
                    "hidden old view cannot confirm, return Back or cancel the newer owner")) return
                secondaryPreview.confirm(); test.phase++
            } else if (test.phase === 22 && !secondaryPreview.visible) {
                var secondaryImage = test.find(secondaryPreview.contentItem, "image-preview-image")
                if (!test.check(test.secondaryConfirmations.length === 1 && test.secondaryConfirmations[0] === state.previewCandidates[0]
                    && test.confirmations.length === 3 && test.cancels === 3 && String(secondaryImage.source) === "",
                    "only the newer owner confirms and model hiding clears its image")) return
                languageWriter.running = true; test.phase++
            } else if (test.phase === 23 && Commons.I18n.rightToLeft) {
                if (!test.check(preview.LayoutMirroring.enabled && preview.LayoutMirroring.childrenInherit
                    && secondaryPreview.LayoutMirroring.enabled && search.LayoutMirroring.enabled,
                    "native RTL language mirrors both preview roots and their controls")) return
                state.selectionState = "preview"
                secondaryPreview.requestActivate()
                test.phase++
            } else if (test.phase === 24 && secondaryPreview.visible) {
                var rtlImage = test.find(secondaryPreview.contentItem, "image-preview-image")
                secondaryPreview.selectedIndex = 0
                rtlImage.parent.forceActiveFocus()
                keyboard.keyClick(Qt.Key_Left)
                if (!test.check(secondaryPreview.selectedIndex === 1, "RTL Left browses forward")) return
                keyboard.keyClick(Qt.Key_Right)
                if (!test.check(secondaryPreview.selectedIndex === 0, "RTL Right browses back")) return
                keyboard.keyClick(Qt.Key_Right, Qt.AltModifier)
                test.phase++
            } else if (test.phase === 25 && !secondaryPreview.visible) {
                if (!test.check(test.secondaryBacks === 1 && test.secondaryConfirmations.length === 1,
                    "RTL Alt Right returns to files without confirmation")) return
                console.log("IMAGE_PREVIEW_KEYBOARD_PASS " + JSON.stringify(test.checks))
                console.log("IMAGE_PREVIEW_PASS native keyboard extension")
                console.log("NATIVE_PASS image preview keyboard"); Qt.quit()
            }
        }
    }
}
