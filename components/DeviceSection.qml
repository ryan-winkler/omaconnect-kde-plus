pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Column {
    id: root

    required property var panel

    width: parent ? parent.width : 0
    spacing: Style.space(12)

    readonly property var bar: panel ? panel.bar : null
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    readonly property string deviceName: panel ? panel.deviceName : "KDE Connect"
    readonly property color foreground: bar ? bar.foreground : "#ffffff"
    readonly property string fontFamily: bar ? bar.fontFamily : "sans-serif"

    readonly property bool showBattery: !panel || (typeof panel.getSetting === "function" ? panel.getSetting("showBatteryStats", true) : true)
    readonly property bool showNetwork: !panel || (typeof panel.getSetting === "function" ? panel.getSetting("showNetworkStats", true) : true)
    readonly property bool showDeviceTypeIcons: !panel || (typeof panel.getSetting === "function" ? panel.getSetting("showDeviceTypeIcons", true) : true)

    Item {
        width: parent.width
        implicitHeight: Math.max(hero.implicitHeight, headerControls.implicitHeight)

        Row {
            id: headerControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            PanelActionButton {
                enabled: !root.service || !root.service.scanning
                iconText: "󰑐"
                tooltipText: "Refresh"
                size: Math.max(44, Style.space(22))
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: if (root.service) root.service.refresh(true)
            }

            PanelActionButton {
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

        Column {
            id: hero
            anchors.left: parent.left
            anchors.right: headerControls.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Row {
                width: parent.width
                spacing: Style.space(6)

                AppearanceIcon {
                    visible: !!root.device
                    width: Style.space(24); height: width
                    icon: root.service ? root.service.appearance.deviceIcon(root.device ? root.device.id : "", root.device ? root.device.type : "") : ({mode:"preset",value:"phone"})
                    assetBaseUrl: root.service ? root.service.appearance.assetBaseUrl : ""
                    foreground: (root.device && root.device.reachable) ? Commons.Color.accent : root.foreground
                    fontFamily: root.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    textFormat: Text.PlainText

                    text: root.device ? root.deviceName : "KDE Connect"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    font.bold: true
                    elide: Text.ElideRight
                    width: Math.max(1, parent.width - (root.showDeviceTypeIcons && !!(root.device && root.device.type && root.device.type !== "unknown") ? Style.space(24) : 0))
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: {
                    if (!root.service) return "Service unavailable"
                    if (root.service.discoveryState !== "ready") return root.service.discoveryMessage
                    return root.service.deviceOverviewStatus(root.device)
                }
                color: (root.service && root.service.discoveryState === "ready" && root.device && root.device.reachable)
                    ? root.foreground
                    : Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
            }

            Row {
                visible: !!(root.device && root.device.reachable && root.service && root.service.deviceBatteryText(root.device, root.showBattery, root.showNetwork) !== "")
                spacing: Style.space(6)

                Text {
                    textFormat: Text.PlainText

                    text: root.service ? ((root.showBattery && root.device && root.device.capabilities && root.device.capabilities.battery && root.device.battery >= 0) ? root.service.deviceBatteryIcon(root.device) : root.service.deviceNetworkIcon(root.device)) : ""
                    color: (root.showBattery && root.device && root.device.capabilities && root.device.capabilities.battery && root.device.battery >= 0 && root.device.battery <= 20 && !(root.device.isCharging || root.device.charging))
                        ? Commons.Color.urgent
                        : ((root.device && (root.device.isCharging || root.device.charging)) ? Commons.Color.accent : root.foreground)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    textFormat: Text.PlainText

                    text: root.service ? root.service.deviceBatteryText(root.device, root.showBattery, root.showNetwork) : ""
                    color: (root.showBattery && root.device && root.device.battery >= 0 && root.device.battery <= 20 && !(root.device.isCharging || root.device.charging))
                        ? Commons.Color.urgent
                        : ((root.device && (root.device.isCharging || root.device.charging)) ? Commons.Color.accent : root.foreground)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: !!(root.showBattery && root.device && root.device.battery >= 0 && root.device.battery <= 20 && !(root.device.isCharging || root.device.charging))
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    Rectangle {
        id: statusBanner
        visible: !!((root.service && (root.service.actionError || root.service.actionMessage || root.service.fileTransferError || root.service.fileTransferMessage)) || (root.panel && root.panel.composerError))
        width: parent.width
        implicitHeight: Math.max(bannerText.implicitHeight, Style.space(18)) + Style.space(8)
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

        MouseArea {
            id: dismissButton
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(18)
            height: Style.space(18)
            cursorShape: Qt.PointingHandCursor
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

            Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: "✕"
                color: ((root.service && (root.service.actionError || root.service.fileTransferError)) || (root.panel && root.panel.composerError)) ? Commons.Color.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                opacity: parent.pressed ? 0.6 : 0.85
            }
        }
    }

    Rectangle {
        visible: !!(panel && panel.incomingRequest)
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
                text: (panel.incomingRequest && panel.incomingRequest.name) ? "Pairing request from " + panel.incomingRequest.name : "Pairing request"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                textFormat: Text.PlainText
                visible: !!(panel.incomingRequest && panel.incomingRequest.verificationKey)
                width: parent.width
                text: "Verify on both devices: " + ((panel.incomingRequest && panel.incomingRequest.verificationKey) ? (root.service ? root.service.formatVerificationKey(panel.incomingRequest.verificationKey) : panel.incomingRequest.verificationKey) : "")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
            }

            Row {
                spacing: Style.space(6)
                Button {
                    text: "Accept"
                    selected: true
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    enabled: !!(root.service && panel.incomingRequest && (!root.service.pendingPairing || !root.service.pendingPairing[panel.incomingRequest.id]))
                    onClicked: if (root.service && panel.incomingRequest) root.service.acceptPairing(panel.incomingRequest.id)
                }
                Button {
                    text: "Reject"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    enabled: !!(root.service && panel.incomingRequest && (!root.service.pendingPairing || !root.service.pendingPairing[panel.incomingRequest.id]))
                    onClicked: if (root.service && panel.incomingRequest) root.service.rejectPairing(panel.incomingRequest.id)
                }
            }
        }
    }

    PanelSeparator {
        foreground: root.foreground
    }

    PanelSectionHeader {
        text: "DEVICES"
        foreground: root.foreground
        fontFamily: root.fontFamily
    }

    ListView {
        id: deviceList
        width: parent.width
        implicitHeight: contentHeight
        height: Math.min(contentHeight, Style.space(220))
        clip: true
        interactive: contentHeight > height
        model: root.service ? root.service.devices : []
        currentIndex: panel.cursorActive ? panel.selectedIndex : -1

        delegate: CursorSurface {
            required property var modelData
            required property int index
            readonly property string devicePendingState: (root.service && root.service.pendingPairing && modelData && root.service.pendingPairing[modelData.id]) ? root.service.pendingPairing[modelData.id] : ""
            readonly property bool isUnpairConfirming: !!(modelData && (panel.unpairConfirmingId === modelData.id || devicePendingState === "unpair_confirm"))
            readonly property bool isCurrent: !!(root.service && modelData && root.service.selectedDeviceId === modelData.id)

            width: deviceList.width
            implicitHeight: row.implicitHeight + Style.space(8)
            hasCursor: !!(modelData && panel.cursorActive && panel.focusSection === "devices" && panel.selectedIndex === index)
            current: isCurrent
            foreground: root.foreground
            fill: Style.hoverFillFor(root.foreground, Commons.Color.accent)
            currentFill: Style.selectedFillFor(root.foreground, Commons.Color.accent)

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (!modelData) return
                    panel.cursorActive = true
                    panel.focusSection = "devices"
                    panel.selectedIndex = index
                    panel.selectDevice(modelData.id)
                }
            }

            Item {
                id: row
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                implicitHeight: Math.max(leftInfoRow.implicitHeight, rightActionItem.implicitHeight) + Style.space(4)

                Row {
                    id: leftInfoRow
                    anchors.left: parent.left
                    anchors.right: rightActionItem.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    AppearanceIcon {
                        width: Style.space(20); height: width
                        icon: root.service && modelData ? root.service.appearance.deviceIcon(modelData.id, modelData.type) : ({mode:"preset",value:"phone"})
                        assetBaseUrl: root.service ? root.service.appearance.assetBaseUrl : ""
                        foreground: (modelData && modelData.paired && modelData.reachable) ? Commons.Color.accent : root.foreground
                        fontFamily: root.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: Style.space(1)
                        width: Math.max(1, leftInfoRow.width - Style.space(28))
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            textFormat: Text.PlainText

                            id: nameText
                            text: root.service && modelData ? root.service.displayName(modelData) : ""
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            font.bold: !!isCurrent
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            textFormat: Text.PlainText

                            visible: !!modelData && (!modelData.paired || !modelData.reachable)
                            text: (!modelData || !modelData.paired) ? "Unpaired" : "Offline"
                            color: Qt.darker(root.foreground, 1.5)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }

                Row {
                    id: rightActionItem
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    PanelActionButton {
                        objectName: "device-settings-" + (modelData ? modelData.id : "")
                        visible: !!modelData && modelData.paired && !isUnpairConfirming
                        enabled: devicePendingState !== "removing"
                        iconText: "󰒓"
                        tooltipText: "Plus device settings"
                        Accessible.role: Accessible.Button
                        Accessible.name: "Plus settings for " + (modelData ? root.service.displayName(modelData) : "device")
                        Accessible.description: "Open settings for this device. Native KDE Connect settings is available inside."
                        Accessible.onPressAction: if (enabled) clicked()
                        focusable: true
                        size: Math.max(44, Style.space(22))
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        onClicked: if (enabled && modelData) panel.openDeviceSettings(modelData.id)
                    }

                    Row {
                        visible: !!modelData && isUnpairConfirming
                        spacing: Style.space(4)

                        Button {
                            height: Math.max(44, implicitHeight)
                            text: "Confirm"
                            selected: true
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            fontSize: Style.font.bodySmall
                            onClicked: if (modelData) panel.confirmUnpair(modelData.id)
                        }

                        Button {
                            height: Math.max(44, implicitHeight)
                            text: "Cancel"
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            fontSize: Style.font.bodySmall
                            onClicked: if (modelData) panel.cancelUnpairConfirm(modelData.id)
                        }
                    }

                    Button {
                        height: Math.max(44, implicitHeight)
                        visible: !!modelData && !isUnpairConfirming && devicePendingState === "requesting"
                        text: "Pairing..."
                        tooltipText: "Click to cancel request"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        fontSize: Style.font.bodySmall
                        onClicked: {
                            if (root.service && modelData) {
                                root.service.setPendingPairing(modelData.id, "")
                                if (typeof root.service.clearActionState === "function") root.service.clearActionState()
                            }
                        }
                    }

                    Button {
                        height: Math.max(44, implicitHeight)
                        visible: !!modelData && !isUnpairConfirming && devicePendingState === "removing"
                        enabled: false
                        text: "Unpairing..."
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        fontSize: Style.font.bodySmall
                    }

                    Row {
                        visible: !isUnpairConfirming && !!modelData && !modelData.paired && modelData.pairRequestedByPeer
                        spacing: Style.space(4)

                        Button {
                            height: Math.max(44, implicitHeight)
                            text: "Accept"
                            selected: true
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            fontSize: Style.font.bodySmall
                            enabled: devicePendingState === ""
                            onClicked: if (root.service && modelData) root.service.acceptPairing(modelData.id)
                        }

                        Button {
                            height: Math.max(44, implicitHeight)
                            text: "Reject"
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            fontSize: Style.font.bodySmall
                            enabled: devicePendingState === ""
                            onClicked: if (root.service && modelData) root.service.rejectPairing(modelData.id)
                        }
                    }

                    Button {
                        height: Math.max(44, implicitHeight)
                        visible: !isUnpairConfirming && !!modelData && !modelData.paired && !modelData.pairRequestedByPeer && devicePendingState !== "requesting"
                        text: "Pair"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        fontSize: Style.font.bodySmall
                        onClicked: {
                            if (modelData) {
                                panel.selectDevice(modelData.id)
                                if (root.service) root.service.pairDevice(modelData.id)
                            }
                        }
                    }

                    Button {
                        height: Math.max(44, implicitHeight)
                        visible: !isUnpairConfirming && !!modelData && modelData.paired && devicePendingState !== "removing"
                        text: "Unpair"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        fontSize: Style.font.bodySmall
                        onClicked: {
                            if (modelData) {
                                panel.selectDevice(modelData.id)
                                panel.requestUnpairConfirm(modelData.id)
                            }
                        }
                    }
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
            text: "KDE Connect setup guide ↗"
            Accessible.name: "Open the official KDE Connect setup guide"
            focusable: true
            foreground: root.foreground
            onClicked: Qt.openUrlExternally("https://kdeconnect.kde.org/users.html")
        }

    }
}
