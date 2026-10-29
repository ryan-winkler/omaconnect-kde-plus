pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Column {
    id: root
    required property var discovery
    property string peerId: ""
    property color foreground: Commons.Color.popups.text
    property string fontFamily: Style.font.family
    property string removalReview: ""
    spacing: Style.space(6)

    Text {
        textFormat: Text.PlainText
        width: root.width
        text: "Saved private addresses"

        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
    }
    Text {
        textFormat: Text.PlainText
        width: root.width
        text: "Approve one private IP for the selected KDE identity. An address does not prove device identity or pairing."

        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
    }
    Controls.TextField {
        id: address
        width: root.width
        placeholderText: "Private IP address"
        Accessible.name: "Private IP address to approve"
        selectByMouse: true
    }
    Controls.ComboBox {
        id: source
        width: root.width
        model: ["manual", "bth", "wireguard"]
        Accessible.name: "Address source"
    }
    Controls.CheckBox {
        id: automatic
        width: root.width
        text: "Allow automatic rediscovery of this address"
        checked: false
        Accessible.name: text
    }
    Kit.Button {
        width: root.width
        height: Math.max(32, implicitHeight)
        text: "Approve and save address"
        enabled: !!root.discovery && !root.discovery.busy && root.peerId !== "" && address.text.trim() !== ""
        focusable: true
        foreground: root.foreground
        Accessible.name: text
        onClicked: if (root.discovery.addAddress(root.peerId, address.text.trim(), source.currentText, automatic.checked)) address.clear()
    }
    Controls.CheckBox {
        width: root.width
        text: "Rediscover approved addresses while this panel is open"
        checked: !!root.discovery && root.discovery.autoDiscoveryEnabled
        onToggled: if (root.discovery) root.discovery.autoDiscoveryEnabled = checked
        Accessible.name: text
    }
    Kit.Button {
        width: root.width
        text: "Refresh devices and addresses"
        enabled: !!root.discovery && !root.discovery.busy
        focusable: true
        foreground: root.foreground
        Accessible.name: text
        onClicked: root.discovery.requestDiscovery(true)
    }
    Repeater {
        model: root.discovery ? root.discovery.addresses : []
        delegate: Column {
            required property var modelData
            width: root.width
            spacing: Style.space(4)
            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: modelData.address + " · " + modelData.source + (modelData.registered ? " · Saved in KDE" : " · Registration unconfirmed") + "\nKDE ID: " + modelData.peer_id

                wrapMode: Text.WrapAnywhere
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
            }
            Controls.CheckBox {
                width: parent.width
                text: "Automatic rediscovery"
                checked: modelData.auto_discover
                enabled: !root.discovery.busy
                Accessible.name: "Automatic rediscovery for " + modelData.address
                onToggled: root.discovery.setAutoDiscover(modelData.peer_id, modelData.address, checked)
            }
            Kit.Button {
                width: parent.width
                text: "Forget local address record"
                enabled: !root.discovery.busy
                focusable: true
                foreground: root.foreground
                Accessible.name: text + " for " + modelData.address
                onClicked: root.discovery.removeAddress(modelData.peer_id, modelData.address, false)
            }
            Kit.Button {
                width: parent.width
                text: root.removalReview === modelData.peer_id + ":" + modelData.address ? "Confirm removal from KDE and local record" : "Review removal from KDE"
                visible: !modelData.manual_baseline
                enabled: !root.discovery.busy
                focusable: true
                foreground: root.foreground
                Accessible.name: text + " for " + modelData.address
                onClicked: {
                    var key = modelData.peer_id + ":" + modelData.address
                    if (root.removalReview === key) {
                        root.discovery.removeAddress(modelData.peer_id, modelData.address, true)
                        root.removalReview = ""
                    } else root.removalReview = key
                }
            }
        }
    }
    Text {
        textFormat: Text.PlainText
        width: root.width
        text: root.discovery ? (root.discovery.error || (root.discovery.busy ? "Saving address changes…" : "External KDE addresses are preserved. Forget removes local metadata only. Automatic discovery runs every 60 seconds while this panel is open.")) : "Address storage is unavailable."

        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
    }
}
