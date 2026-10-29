pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Column {
    id: root
    required property var service
    property var device: service ? service.selectedDevice : null
    property string feedback: ""
    readonly property var store: service ? service.appearance : null
    readonly property string linkedId: store && device ? String(store.deviceAppearance(device.id).syncthing_device_id || "") : ""
    spacing: Style.space(6)
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "Syncthing association"

        color: Commons.Color.popups.text
        font.bold: true
        font.pixelSize: Style.font.body
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "KDE ID: " + (root.device ? root.device.id : "Select a device first") + "\nLinked Syncthing ID: " + (root.linkedId || "None")

        wrapMode: Text.WrapAnywhere
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Controls.TextField {
        id: syncthingId
        width: parent.width
        placeholderText: "Full Syncthing device ID"
        Accessible.name: "Full Syncthing device ID to link to the selected KDE identity"
        selectByMouse: true
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "Check both full identities in their owner apps. A local link does not pair devices, start sync or verify ownership."

        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Kit.Button {
        width: parent.width
        text: "Confirm these two identities"
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: !!root.device && !!root.store && !root.store.busy && syncthingId.text.trim() !== ""
        Accessible.name: text
        onClicked: {
            root.store.linkSyncthing(root.device.id, syncthingId.text.trim())
            root.feedback = "Check the saved link above. "
        }
    }
    Kit.Button {
        width: parent.width
        text: "Remove local link"
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: !!root.device && !!root.linkedId && !!root.store && !root.store.busy
        Accessible.name: text
        onClicked: root.store.linkSyncthing(root.device.id, "")
    }
    Kit.Button {
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
        text: (root.store ? root.store.error : "") || (root.service ? root.service.ownerPanelMessage : "") || root.feedback

        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
}
