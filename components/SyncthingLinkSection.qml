pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Column {
    id: root
    required property var service
    property var device: service ? service.selectedDevice : null
    readonly property var store: service ? service.appearance : null
    readonly property string peerId: device ? String(device.id || "") : ""
    readonly property string linkedId: store && peerId ? String(store.deviceAppearance(peerId).syncthing_device_id || "") : ""
    property string draftPeerId: ""
    property string draft: ""
    property bool edited: false
    property var pending: null
    property string feedback: ""
    readonly property bool busy: !!pending || !!(store && store.busy)
    readonly property bool validDraft: /^[A-Z2-7]{7}(?:-[A-Z2-7]{7}){7}$/.test(draft.trim())
    spacing: Style.space(6)

    function rebaseDraft() {
        draftPeerId = peerId
        edited = false
        draft = linkedId
        feedback = ""
    }
    function requestLink(remove) {
        if (!store || !peerId || busy) return false
        if (draftPeerId !== peerId) {
            rebaseDraft()
            feedback = "Device changed. Compare both identities before saving a note."
            return false
        }
        var value = remove ? "" : draft.trim()
        if (remove ? !linkedId : (!validDraft || value === linkedId)) return false
        // The request keeps its reviewed KDE identity even if selection changes.
        pending = {peerId: peerId, value: value}
        feedback = remove ? "Removing local note…" : "Saving local note…"
        if (!store.linkSyncthing(pending.peerId, value)) {
            pending = null
            feedback = "The request did not start. Check the saved note and try again."
            return false
        }
        return true
    }
    function confirmReadback() {
        if (!pending || !store) return
        var request = pending
        pending = null
        var actual = String(store.deviceAppearance(request.peerId).syncthing_device_id || "")
        if (actual !== request.value) {
            feedback = "The note was not confirmed by saved readback. Check it before trying again."
            return
        }
        if (request.peerId !== peerId) {
            feedback = "The request was applied to the previous KDE device. Select it to check its saved note."
            return
        }
        edited = false
        draft = actual
        feedback = actual ? "Local identity note saved." : "Local identity note removed."
    }
    readonly property string syncState: service && service.syncthingDeviceId === linkedId ? String(service.syncthingState || "") : ""
    function readSyncState() { if (service && linkedId && visible) service.readSyncthingPause(linkedId) }
    onVisibleChanged: readSyncState()
    onPeerIdChanged: rebaseDraft()
    onStoreChanged: rebaseDraft()
    onLinkedIdChanged: {
        if (!edited && draftPeerId === peerId) draft = linkedId
        readSyncState()
    }
    Component.onCompleted: { rebaseDraft(); readSyncState() }
    Connections {
        target: root.store
        ignoreUnknownSignals: true
        function onSaved() { root.confirmReadback() }
        function onOperationFailed(message) {
            if (!root.pending) return
            var previous = root.pending.peerId !== root.peerId
            root.pending = null
            root.feedback = previous
                ? "The previous device's note was not confirmed. Select it to check the saved note."
                : "Local note not confirmed. " + (message || "Check the saved note before trying again.")
        }
    }

    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "Syncthing identity note"
        color: Commons.Color.popups.text
        font.bold: true
        font.pixelSize: Style.font.body
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "Keep an optional local note to recognize the same device in both apps. Compare its name and full IDs in KDE Connect and Syncthing. This note does not verify ownership, pair devices or start synchronization."
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: root.device ? "KDE device: " + (root.device.name || root.peerId) + "\nKDE ID: " + root.peerId : "Select a KDE device first."
        wrapMode: Text.WrapAnywhere
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "Saved Syncthing ID — select to copy"
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.bodySmall
    }
    Kit.TextField {
        objectName: "syncthing-saved-id"
        width: parent.width
        text: root.linkedId
        placeholderText: "No saved identity note"
        readOnly: true
        selectByMouse: true
        Accessible.name: "Saved full Syncthing device ID; select to copy"
    }
    Text {
        objectName: "syncthing-pause-state"
        textFormat: Text.PlainText
        width: parent.width
        visible: !!root.linkedId
        text: root.syncState === "paused" ? "Syncthing: paused for this device."
            : root.syncState === "active" ? "Syncthing: not paused for this device."
            : root.syncState === "unknown" ? "Syncthing state unknown. Syncthing may not run, or it does not know this device ID."
            : "Checking Syncthing…"
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Kit.Button {
        objectName: "syncthing-pause"
        width: parent.width
        visible: !!root.linkedId
        text: root.syncState === "paused" ? "Resume in Syncthing" : "Pause in Syncthing"
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: (root.syncState === "paused" || root.syncState === "active") && !!root.service && !root.service.syncthingBusy
        Accessible.name: text + " for the saved device ID"
        onClicked: root.service.setSyncthingPaused(root.linkedId, root.syncState !== "paused")
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        visible: !!root.linkedId
        text: "Pause stops Syncthing from syncing with this device until you resume. Syncthing keeps its folders, keys and settings."
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Text {
        width: parent.width
        text: "Syncthing device ID"
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.bodySmall
    }
    Kit.TextField {
        id: syncthingId
        objectName: "syncthing-note-editor"
        width: parent.width
        text: root.draft
        placeholderText: "Full Syncthing device ID"
        maximumLength: 63
        enabled: !root.busy && root.peerId !== ""
        Accessible.name: "Full Syncthing device ID to note for the selected KDE identity"
        selectByMouse: true
        onTextEdited: { root.edited = true; root.draft = text }
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "Paste all eight groups from Syncthing's Show ID view. Save applies only to the KDE device named above."
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Kit.Button {
        objectName: "syncthing-save"
        width: parent.width
        text: "Save local identity note"
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: !!root.peerId && !!root.store && !root.busy && root.draftPeerId === root.peerId && root.validDraft && root.draft.trim() !== root.linkedId
        Accessible.name: text
        onClicked: root.requestLink(false)
    }
    Kit.Button {
        objectName: "syncthing-remove"
        width: parent.width
        text: "Remove local note"
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: !!root.peerId && !!root.linkedId && !!root.store && !root.busy
        Accessible.name: text
        onClicked: root.requestLink(true)
    }
    Text {
        objectName: "syncthing-note-feedback"
        textFormat: Text.PlainText
        width: parent.width
        visible: text !== ""
        text: root.feedback || (root.store ? root.store.error : "")
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Kit.Button {
        objectName: "syncthing-owner"
        width: parent.width
        text: "Open existing Syncthing panel"
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: !!root.service
        Accessible.name: text
        onClicked: root.service.openSyncthingPanel()
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "Opens the existing Syncshell panel. It is a general panel, not a link to this particular device."
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Text {
        objectName: "syncthing-owner-feedback"
        textFormat: Text.PlainText
        width: parent.width
        visible: text !== ""
        text: root.service ? root.service.ownerPanelMessage : ""
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Kit.Button {
        width: parent.width
        text: "Syncthing device setup help ↗"
        Accessible.name: "Open official Syncthing device setup help"
        foreground: Commons.Color.popups.text
        focusable: true
        onClicked: Qt.openUrlExternally("https://docs.syncthing.net/intro/getting-started.html")
    }
}
