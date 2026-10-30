pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Column {
    id: root
    required property var discovery
    property bool showTitle: true
    property string peerId: ""
    property color foreground: Commons.Color.popups.text
    property string fontFamily: Style.font.family
    property string removalReview: ""
    property string pendingAddress: ""
    spacing: Style.space(6)

    // Keep the typed address until saved readback contains it, so a failed save needs no retyping.
    Connections {
        target: root.discovery
        ignoreUnknownSignals: true
        function onAddressesChanged() {
            var saved = root.pendingAddress
            root.pendingAddress = ""
            if (saved && address.text.trim() === saved && root.discovery.addresses.some(function(row) { return row.peer_id === root.peerId && row.address === saved }))
                address.clear()
        }
    }

    Text {
        visible: root.showTitle
        textFormat: Text.PlainText
        width: root.width
        text: "Saved LAN and VPN addresses"

        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
    }
    Text {
        textFormat: Text.PlainText
        width: root.width
        text: "Save an IP address that KDE Connect can use to reach this device over LAN, Back to Home, WireGuard or Tailscale. Saving an address does not pair the device."

        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }
    Text {
        width: parent.width
        text: "IP address"
        textFormat: Text.PlainText
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Controls.TextField {
        id: address
        width: root.width
        placeholderText: "Private or Tailscale IP address"
        Accessible.name: "LAN or VPN IP address to approve"
        selectByMouse: true
    }
    Text {
        width: parent.width
        text: "Address source"
        textFormat: Text.PlainText
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Controls.ComboBox {
        id: source
        width: root.width
        model: [
            {label: "LAN / manual", value: "manual"},
            {label: "MikroTik Back to Home", value: "bth"},
            {label: "WireGuard", value: "wireguard"},
            {label: "Tailscale", value: "tailscale"}
        ]
        textRole: "label"
        valueRole: "value"
        Accessible.name: "Address source"
    }
    Controls.CheckBox {
        id: automatic
        width: root.width
        text: "Allow automatic rediscovery of this address"
        checked: false
        Accessible.name: text
    }
    SettingsButton {
        width: root.width
        height: Math.max(32, implicitHeight)
        text: "Approve and save address"
        enabled: !!root.discovery && !root.discovery.busy && root.peerId !== "" && address.text.trim() !== ""
        focusable: true
        foreground: root.foreground
        Accessible.name: text
        onClicked: if (root.discovery.addAddress(root.peerId, address.text.trim(), source.currentValue, automatic.checked)) root.pendingAddress = address.text.trim()
    }
    Controls.CheckBox {
        width: root.width
        text: "Rediscover approved addresses while this panel is open"
        checked: !!root.discovery && root.discovery.autoDiscoveryEnabled
        onToggled: if (root.discovery) root.discovery.autoDiscoveryEnabled = checked
        Accessible.name: text
    }
    SettingsButton {
        width: root.width
        text: "Refresh devices and addresses"
        enabled: !!root.discovery && !root.discovery.busy
        focusable: true
        foreground: root.foreground
        Accessible.name: text
        onClicked: root.discovery.requestDiscovery(true)
    }
    Connections {
        target: root
        function onPeerIdChanged() {
            address.clear()
            source.currentIndex = 0
            automatic.checked = false
            root.removalReview = ""
        }
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
                onToggled: root.discovery.setAutoDiscover(modelData.peer_id, modelData.address, checked, modelData.source)
            }
            SettingsButton {
                width: parent.width
                text: "Forget local address record"
                enabled: !root.discovery.busy
                focusable: true
                foreground: root.foreground
                Accessible.name: text + " for " + modelData.address
                onClicked: root.discovery.removeAddress(modelData.peer_id, modelData.address, false, modelData.source)
            }
            SettingsButton {
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
                        root.discovery.removeAddress(modelData.peer_id, modelData.address, true, modelData.source)
                        root.removalReview = ""
                    } else root.removalReview = key
                }
            }
        }
    }
    Text {
        textFormat: Text.PlainText
        width: root.width
        text: root.discovery ? (root.discovery.error || (root.discovery.busy ? "Saving address changes…" : "Forget removes only the Plus record. Addresses you added in KDE Connect stay. When enabled, automatic rediscovery checks every 60 seconds while this panel is open.")) : "Address storage is unavailable."

        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }
}
