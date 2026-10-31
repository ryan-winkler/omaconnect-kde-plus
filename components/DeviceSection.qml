pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Column {
    id: root
    required property var panel
    property bool detailsExpanded: true
    signal detailsToggleRequested()

    width: parent ? parent.width : 0
    spacing: Style.space(8)
    readonly property var bar: panel ? panel.bar : null
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    readonly property color foreground: bar ? bar.foreground : Commons.Color.popups.text
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property bool showBattery: !panel || (typeof panel.getSetting === "function" ? panel.getSetting("showBatteryStats", true) : true)
    readonly property bool showNetwork: !panel || (typeof panel.getSetting === "function" ? panel.getSetting("showNetworkStats", true) : true)
    readonly property string pendingState: service && service.pendingPairing && device ? service.pendingPairing[device.id] || "" : ""
    readonly property var incomingRequest: device && device.pairRequestedByPeer ? device : panel ? panel.incomingRequest : null
    readonly property bool isUnpairConfirming: !!(device && (panel.unpairConfirmingId === device.id || pendingState === "unpair_confirm"))

    Row {
        width: parent.width
        spacing: Style.space(4)
        DeviceSwitcher {
            id: devicePicker
            objectName: "daily-device-selector"
            width: Math.max(0, parent.width - refreshButton.width - settingsButton.width - parent.spacing * 2)
            panel: root.panel
        }
        PanelActionButton {
            id: refreshButton
            enabled: !!root.service && !root.service.scanning
            iconText: "󰑐"
            tooltipText: "Refresh devices"
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: "Refresh devices"
            Accessible.onPressAction: if (enabled) clicked()
            size: Math.max(44, Style.space(22))
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: if (root.service) root.service.refresh(true)
        }
        PanelActionButton {
            id: settingsButton
            objectName: "selected-device-settings"
            iconText: "󰒓"
            tooltipText: "Plus device settings"
            Accessible.role: Accessible.Button
            Accessible.name: "Plus device settings"
            Accessible.description: "Open this device's Plus settings, with a link to native KDE Connect settings."
            Accessible.onPressAction: if (enabled) clicked()
            focusable: true
            size: Math.max(44, Style.space(22))
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: {
                if (root.device) panel.openDeviceSettings(root.device.id)
                else panel.openSettings("Device features")
            }
        }
    }
    Rectangle {
        id: statusBanner
        objectName: "device-status-banner"
        visible: !!((root.service && (root.service.actionError || root.service.actionMessage || root.service.fileTransferError || root.service.fileTransferMessage)) || (root.panel && root.panel.composerError))
        width: parent.width
        implicitHeight: Math.max(bannerText.implicitHeight, dismissButton.implicitHeight) + Style.space(8)
        radius: Style.cornerRadius
        color: ((root.service && (root.service.actionError || root.service.fileTransferError)) || (root.panel && root.panel.composerError))
            ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.15)
            : Style.hoverFillFor(root.foreground, Commons.Color.accent)

        Text {
            textFormat: Text.PlainText
            id: bannerText
            anchors.left: parent.left
            anchors.right: dismissButton.left
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (root.service && root.service.actionError) return root.service.actionError
                if (root.service && root.service.fileTransferError) return root.service.fileTransferError
                if (root.panel && root.panel.composerError) return root.panel.composerError
                if (root.service && root.service.actionMessage) return root.service.actionMessage
                if (root.service && root.service.fileTransferMessage) return root.service.fileTransferMessage
                return ""
            }
            color: ((root.service && (root.service.actionError || root.service.fileTransferError)) || (root.panel && root.panel.composerError)) ? Commons.Color.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
        }

        PanelActionButton {
            id: dismissButton
            objectName: "dismiss-device-status"
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            size: Math.max(44, Style.space(22))
            iconText: "󰅖"
            tooltipText: "Dismiss device status"
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: "Dismiss device status"
            Accessible.onPressAction: if (enabled) clicked()
            foreground: ((root.service && (root.service.actionError || root.service.fileTransferError)) || (root.panel && root.panel.composerError)) ? Commons.Color.urgent : root.foreground
            fontFamily: root.fontFamily
            onClicked: {
                if (root.service) {
                    root.service.actionMessage = ""
                    root.service.actionError = ""
                    if (!root.service.fileBusy) {
                        root.service.fileTransferMessage = ""
                        root.service.fileTransferError = ""
                    }
                }
                if (root.panel) {
                    root.panel.composerError = ""
                }
            }
        }
    }

    Rectangle {
        objectName: "incoming-pairing-warning"
        visible: !!(panel && root.incomingRequest)
        width: parent.width
        implicitHeight: incomingContent.implicitHeight + Style.space(16)
        radius: Style.cornerRadius
        color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.14)
        border.color: Commons.Color.accent
        border.width: 1

        Column {
            id: incomingContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(8)
            spacing: Style.space(6)

            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: (root.incomingRequest && root.incomingRequest.name) ? "Pairing request from " + root.incomingRequest.name : "Pairing request"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                textFormat: Text.PlainText
                visible: !!(root.incomingRequest && root.incomingRequest.verificationKey)
                width: parent.width
                wrapMode: Text.WrapAnywhere
                text: "Verify on both devices: " + ((root.incomingRequest && root.incomingRequest.verificationKey) ? (root.service ? root.service.formatVerificationKey(root.incomingRequest.verificationKey) : root.incomingRequest.verificationKey) : "")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
            }

            Row {
                spacing: Style.space(6)
                Button {
                    height: Math.max(44, implicitHeight)
                    focusable: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Accept pairing request"
                    Accessible.onPressAction: if (enabled) clicked()
                    text: "Accept"
                    bordered: true
                    selected: true
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    enabled: !!(root.service && root.incomingRequest && (!root.service.pendingPairing || !root.service.pendingPairing[root.incomingRequest.id]))
                    onClicked: if (root.service && root.incomingRequest) root.service.acceptPairing(root.incomingRequest.id)
                }
                Button {
                    height: Math.max(44, implicitHeight)
                    focusable: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Reject pairing request"
                    Accessible.onPressAction: if (enabled) clicked()
                    text: "Reject"
                    bordered: true
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    enabled: !!(root.service && root.incomingRequest && (!root.service.pendingPairing || !root.service.pendingPairing[root.incomingRequest.id]))
                    onClicked: if (root.service && root.incomingRequest) root.service.rejectPairing(root.incomingRequest.id)
                }
            }
        }
    }

    Column {
        objectName: "device-unpair-confirmation"
        width: parent.width
        visible: root.isUnpairConfirming
        spacing: Style.space(4)
        Text {
            width: parent.width
            text: "Remove KDE Connect pairing? Confirm only if you want to remove trust for this device."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
        }
        Flow {
            width: parent.width
            spacing: Style.space(4)
            Button {
                text: "Confirm unpair"
                bordered: true
                height: Math.max(44, implicitHeight)
                selected: true
                focusable: true
                Accessible.role: Accessible.Button
                Accessible.name: "Confirm unpair selected device"
                Accessible.onPressAction: if (enabled) clicked()
                foreground: Commons.Color.urgent
                accent: Commons.Color.urgent
                fontFamily: root.fontFamily
                onClicked: if (root.device) panel.confirmUnpair(root.device.id)
            }
            Button {
                text: "Cancel"
                bordered: true
                height: Math.max(44, implicitHeight)
                focusable: true
                Accessible.role: Accessible.Button
                Accessible.name: "Cancel unpair selected device"
                Accessible.onPressAction: if (enabled) clicked()
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: if (root.device) panel.cancelUnpairConfirm(root.device.id)
            }
        }
    }
    // One region for everything about the selected device, styled like the other sections.
    DailySection {
        sectionId: "devices"
        visible: !!root.device
        title: "Device details"
        description: "Status, battery, network, ID and pairing for the selected device."
        expanded: root.detailsExpanded
        onToggleRequested: root.detailsToggleRequested()
        Column {
            objectName: "selected-device-details"
            width: parent.width
            spacing: Style.space(6)
            Text {
                width: parent.width
                text: root.service ? root.service.deviceOverviewStatus(root.device) : ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
            }
            DeviceInformationSection {
                width: parent.width
                service: root.service
                showTitle: false
                showBattery: root.showBattery
                showCellular: root.showNetwork
            }
            Flow {
                width: parent.width
                spacing: Style.space(4)
                Button {
                    visible: root.pendingState === "requesting"
                    text: "Cancel pairing request"
                    bordered: true
                    height: Math.max(44, implicitHeight)
                    focusable: true
                    Accessible.role: Accessible.Button
                    Accessible.name: text
                    Accessible.onPressAction: if (enabled) clicked()
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    onClicked: if (root.service && root.device) {
                        root.service.setPendingPairing(root.device.id, "")
                        root.service.clearActionState()
                    }
                }
                Button {
                    visible: root.pendingState === "removing"
                    enabled: false
                    text: "Unpairing…"
                    bordered: true
                    height: Math.max(44, implicitHeight)
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                }
                Button {
                    visible: !!root.device && !root.device.paired && root.pendingState === "" && !root.device.pairRequestedByPeer
                    text: "Pair"
                    bordered: true
                    height: Math.max(44, implicitHeight)
                    focusable: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Pair selected device"
                    Accessible.onPressAction: if (enabled) clicked()
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    onClicked: if (root.service && root.device) root.service.pairDevice(root.device.id)
                }
                Button {
                    visible: !!root.device && root.device.paired && !root.isUnpairConfirming && root.pendingState !== "removing"
                    text: "Unpair"
                    bordered: true
                    height: Math.max(44, implicitHeight)
                    focusable: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Unpair selected device"
                    Accessible.onPressAction: if (enabled) clicked()
                    foreground: Commons.Color.urgent
                    accent: Commons.Color.urgent
                    fontFamily: root.fontFamily
                    onClicked: if (root.device) panel.requestUnpairConfirm(root.device.id)
                }
            }
        }
    }
    Column {
        visible: !root.service || root.service.devices.length === 0
        spacing: Style.space(6)
        width: parent.width

        Text {
            textFormat: Text.PlainText
            text: {
                if (root.service && root.service.scanning) return "Scanning..."
                if (root.service && root.service.discoveryState === "not_installed") return "Required packages missing"
                if (root.service && root.service.discoveryState === "unavailable") return "KDE Connect unavailable"
                return "No devices found"
            }
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
        }

        Text {
            width: parent.width
            text: root.service && root.service.discoveryState === "not_installed"
                ? "Run this command in a terminal to install KDE Connect, then select Refresh. To copy it, focus the command and press Ctrl+C."
                : "Pair devices in KDE Connect. The setup guide helps with connection problems."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
        }
        TextField {
            objectName: "kdeconnect-install-command"
            visible: !!root.service && root.service.discoveryState === "not_installed"
            width: parent.width
            // Shown for copying only; Plus never runs it.
            text: "omarchy pkg add kdeconnect python python-gobject"
            readOnly: true
            selectByMouse: true
            foreground: root.foreground
            Accessible.name: "KDE Connect install command; focus and press Control+C to copy"
            onActiveFocusChanged: if (activeFocus) selectAll()
        }
        Button {
            height: Math.max(44, implicitHeight)
            text: "KDE Connect setup guide ↗"
            bordered: true
            Accessible.name: "Open the official KDE Connect setup guide"
            Accessible.onPressAction: if (enabled) clicked()
            focusable: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: Qt.openUrlExternally("https://kdeconnect.kde.org/users.html")
        }

    }
}
