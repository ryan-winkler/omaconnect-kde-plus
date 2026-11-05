pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit
import "../i18n" as Locale

Column {
    id: root
    function sourceLabel(value) { return value ? Locale.Strings.t("savedAddresses.source." + value) : "" }
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
        text: Locale.Strings.t("savedAddresses.savedLanAndVpnAddresses")

        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
    }
    Text {
        textFormat: Text.PlainText
        width: root.width
        text: Locale.Strings.t("savedAddresses.saveAnIpAddressThatKde")

        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }
    Text {
        width: parent.width
        text: Locale.Strings.t("savedAddresses.ipAddress")
        textFormat: Text.PlainText
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Controls.TextField {
        id: address
        width: root.width
        placeholderText: Locale.Strings.t("savedAddresses.privateOrTailscaleIpAddress")
        Accessible.name: Locale.Strings.t("savedAddresses.lanOrVpnIpAddressTo")
        selectByMouse: true
    }
    Text {
        width: parent.width
        text: Locale.Strings.t("savedAddresses.addressSource")
        textFormat: Text.PlainText
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Controls.ComboBox {
        id: source
        width: root.width
        model: ["manual", "bth", "wireguard", "tailscale"]
        displayText: root.sourceLabel(currentValue)
        delegate: Controls.ItemDelegate {
            required property string modelData
            required property int index
            width: source.width
            text: root.sourceLabel(modelData)
            highlighted: source.highlightedIndex === index
        }
        Accessible.name: Locale.Strings.t("savedAddresses.addressSource")
    }
    Controls.CheckBox {
        id: automatic
        width: root.width
        text: Locale.Strings.t("savedAddresses.allowAutomaticRediscoveryOfThisAddress")
        checked: false
        Accessible.name: text
    }
    SettingsButton {
        width: root.width
        height: Math.max(32, implicitHeight)
        text: Locale.Strings.t("savedAddresses.approveAndSaveAddress")
        enabled: !!root.discovery && !root.discovery.busy && root.peerId !== "" && address.text.trim() !== ""
        focusable: true
        foreground: root.foreground
        Accessible.name: text
        onClicked: if (root.discovery.addAddress(root.peerId, address.text.trim(), source.currentValue, automatic.checked)) root.pendingAddress = address.text.trim()
    }
    Controls.CheckBox {
        width: root.width
        text: Locale.Strings.t("savedAddresses.rediscoverApprovedAddressesWhileThisPanel")
        checked: !!root.discovery && root.discovery.autoDiscoveryEnabled
        onToggled: if (root.discovery) root.discovery.autoDiscoveryEnabled = checked
        Accessible.name: text
    }
    SettingsButton {
        width: root.width
        text: Locale.Strings.t("savedAddresses.refreshDevicesAndAddresses")
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
                text: modelData.address + " · " + modelData.source + (modelData.registered ? Locale.Strings.t("savedAddresses.savedInKde") : Locale.Strings.t("savedAddresses.registrationUnconfirmed")) + "\nKDE ID: " + modelData.peer_id

                wrapMode: Text.WrapAnywhere
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
            }
            Controls.CheckBox {
                width: parent.width
                text: Locale.Strings.t("savedAddresses.automaticRediscovery")
                checked: modelData.auto_discover
                enabled: !root.discovery.busy
                Accessible.name: Locale.Strings.format("savedAddresses.rediscoverAddress", [modelData.address])
                onToggled: root.discovery.setAutoDiscover(modelData.peer_id, modelData.address, checked, modelData.source)
            }
            SettingsButton {
                width: parent.width
                text: Locale.Strings.t("savedAddresses.forgetLocalAddressRecord")
                enabled: !root.discovery.busy
                focusable: true
                foreground: root.foreground
                Accessible.name: Locale.Strings.format("savedAddresses.addressAction", [text, modelData.address])
                onClicked: root.discovery.removeAddress(modelData.peer_id, modelData.address, false, modelData.source)
            }
            SettingsButton {
                width: parent.width
                text: root.removalReview === modelData.peer_id + ":" + modelData.address ? Locale.Strings.t("savedAddresses.confirmRemovalFromKdeAndLocal") : Locale.Strings.t("savedAddresses.reviewRemovalFromKde")
                visible: !modelData.manual_baseline
                enabled: !root.discovery.busy
                focusable: true
                foreground: root.foreground
                Accessible.name: Locale.Strings.format("savedAddresses.addressAction", [text, modelData.address])
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
        text: root.discovery ? (root.discovery.error || (root.discovery.busy ? Locale.Strings.t("savedAddresses.savingAddressChanges") : Locale.Strings.t("savedAddresses.forgetRemovesOnlyThePlusRecord"))) : Locale.Strings.t("savedAddresses.addressStorageIsUnavailable")

        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }
}
