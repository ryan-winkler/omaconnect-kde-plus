pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit
import "../i18n" as Locale

Column {
    id: root
    required property var service
    property bool panelOpened: false
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
            feedback = Locale.Strings.live("syncthingLink.deviceChanged")
            return false
        }
        var value = remove ? "" : draft.trim()
        if (remove ? !linkedId : (!validDraft || value === linkedId)) return false
        // The request keeps its reviewed KDE identity even if selection changes.
        pending = {peerId: peerId, value: value}
        feedback = remove ? Locale.Strings.live("syncthingLink.removing") : Locale.Strings.live("syncthingLink.saving")
        if (!store.linkSyncthing(pending.peerId, value)) {
            pending = null
            feedback = Locale.Strings.live("syncthingLink.requestFailed")
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
            feedback = Locale.Strings.live("syncthingLink.readbackUnconfirmed")
            return
        }
        if (request.peerId !== peerId) {
            feedback = Locale.Strings.live("syncthingLink.previousApplied")
            return
        }
        edited = false
        draft = actual
        feedback = actual ? Locale.Strings.live("syncthingLink.saved") : Locale.Strings.live("syncthingLink.removed")
    }
    readonly property string syncState: service && service.syncthingDeviceId === linkedId ? String(service.syncthingState || "") : ""
    function readSyncState() { if (service && linkedId && visible && panelOpened) service.readSyncthingPause(linkedId) }
    Timer {
        interval: 15000
        repeat: true
        running: root.panelOpened && root.visible && !!root.linkedId
        onTriggered: root.readSyncState()
    }
    onVisibleChanged: readSyncState()
    onPanelOpenedChanged: readSyncState()
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
                ? Locale.Strings.live("syncthingLink.previousUnconfirmed")
                : message ? Locale.Strings.format("syncthingLink.unconfirmedWithDetail", [message]) : Locale.Strings.live("syncthingLink.unconfirmed")
        }
    }

    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: Locale.Strings.t("syncthingLink.syncthingIdentityNote")
        color: Commons.Color.popups.text
        font.bold: true
        font.pixelSize: Style.font.body
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: Locale.Strings.t("syncthingLink.keepAnOptionalLocalNoteTo")
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: root.device ? Locale.Strings.format("syncthingLink.deviceId", [root.device.name || root.peerId, root.peerId]) : Locale.Strings.t("syncthingLink.selectAKdeDeviceFirst")
        wrapMode: Text.WrapAnywhere
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: Locale.Strings.t("syncthingLink.savedSyncthingIdSelectToCopy")
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.bodySmall
    }
    Kit.TextField {
        objectName: "syncthing-saved-id"
        width: parent.width
        text: root.linkedId
        placeholderText: Locale.Strings.t("syncthingLink.noSavedIdentityNote")
        readOnly: true
        selectByMouse: true
        Accessible.name: Locale.Strings.t("syncthingLink.savedFullSyncthingDeviceIdSelect")
    }
    Text {
        objectName: "syncthing-pause-state"
        textFormat: Text.PlainText
        width: parent.width
        visible: !!root.linkedId
        text: root.syncState === "paused" ? Locale.Strings.t("syncthingLink.syncthingLastCheckPausedForThis")
            : root.syncState === "active" ? Locale.Strings.t("syncthingLink.syncthingLastCheckNotPausedFor")
            : root.syncState === "unknown" ? Locale.Strings.t("syncthingLink.syncthingStateUnknownPlusCouldNot")
            : Locale.Strings.t("syncthingLink.checkingSyncthing")
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    SettingsButton {
        objectName: "syncthing-refresh"
        width: parent.width
        visible: !!root.linkedId
        text: Locale.Strings.t("syncthingLink.refreshSyncthingState")
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: !!root.service && !root.service.syncthingBusy
        onClicked: root.readSyncState()
    }
    SettingsButton {
        objectName: "syncthing-pause"
        width: parent.width
        visible: !!root.linkedId
        text: root.syncState === "paused" ? Locale.Strings.t("syncthingLink.resumeInSyncthing") : Locale.Strings.t("syncthingLink.pauseInSyncthing")
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: (root.syncState === "paused" || root.syncState === "active") && !!root.service && !root.service.syncthingBusy
        Accessible.name: Locale.Strings.format("syncthingLink.savedIdAction", [text])
        onClicked: root.service.setSyncthingPaused(root.linkedId, root.syncState !== "paused")
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        visible: !!root.linkedId
        text: Locale.Strings.t("syncthingLink.pauseStopsSyncthingFromSyncingWith")
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Text {
        width: parent.width
        text: Locale.Strings.t("syncthingLink.syncthingDeviceId")
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.bodySmall
    }
    Kit.TextField {
        id: syncthingId
        objectName: "syncthing-note-editor"
        width: parent.width
        text: root.draft
        placeholderText: Locale.Strings.t("syncthingLink.fullSyncthingDeviceId")
        maximumLength: 63
        enabled: !root.busy && root.peerId !== ""
        Accessible.name: Locale.Strings.t("syncthingLink.fullSyncthingDeviceIdToNote")
        selectByMouse: true
        onTextEdited: { root.edited = true; root.draft = text }
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: Locale.Strings.t("syncthingLink.pasteAllEightGroupsFromSyncthing")
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    SettingsButton {
        objectName: "syncthing-save"
        width: parent.width
        text: Locale.Strings.t("syncthingLink.saveLocalIdentityNote")
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: !!root.peerId && !!root.store && !root.busy && root.draftPeerId === root.peerId && root.validDraft && root.draft.trim() !== root.linkedId
        Accessible.name: text
        onClicked: root.requestLink(false)
    }
    SettingsButton {
        objectName: "syncthing-remove"
        width: parent.width
        text: Locale.Strings.t("syncthingLink.removeLocalNote")
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
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    SettingsButton {
        objectName: "syncthing-owner"
        width: parent.width
        text: Locale.Strings.t("syncthingLink.openExistingSyncthingPanel")
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: !!root.service
        Accessible.name: text
        onClicked: root.service.openSyncthingPanel()
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: Locale.Strings.t("syncthingLink.opensTheExistingSyncshellPanelIt")
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Text {
        objectName: "syncthing-owner-feedback"
        textFormat: Text.PlainText
        width: parent.width
        visible: text !== ""
        text: root.service ? root.service.ownerPanelMessage : ""
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    SettingsButton {
        width: parent.width
        text: Locale.Strings.t("syncthingLink.syncthingDeviceSetupHelp")
        Accessible.name: Locale.Strings.t("syncthingLink.openOfficialSyncthingDeviceSetupHelp")
        foreground: Commons.Color.popups.text
        focusable: true
        onClicked: Qt.openUrlExternally("https://docs.syncthing.net/intro/getting-started.html")
    }
}
