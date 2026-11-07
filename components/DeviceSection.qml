pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../i18n" as Locale

Column {
    id: root
    required property var panel
    property bool detailsExpanded: true
    property bool showDetails: true
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
    readonly property bool unpairPending: !!(service && device && service.unpairPendingId === device.id)
    readonly property var incomingRequest: device && device.requestKnown !== false && device.pairRequestedByPeer ? device : panel ? panel.incomingRequest : null
    readonly property var outgoingRequest: isOutgoing(device) ? device
        : service ? service.devices.find(isOutgoing) || null : null
    readonly property bool partialRoster: !!(service && service.discoveryState === "partial")
    readonly property bool pairAvailable: !!(device && device.pairingKnown !== false && !device.paired && device.reachable)
    readonly property bool emptyRoster: !!(service && service.daemonAvailable && service.discoveryState === "ready"
        && !service.scanning && service.devices.length === 0)
    readonly property bool handoffAvailable: !!(incomingRequest || outgoingRequest || partialRoster || pairAvailable || emptyRoster
        || (device && (device.pairingKnown === false || device.reachabilityKnown === false)))
    readonly property bool isUnpairConfirming: !!(device && device.paired && device.pairingReported === true
        && panel.unpairConfirmingId === device.id)

    function isOutgoing(peer) {
        return !!(peer && peer.requestKnown !== false && peer.pairRequested)
    }

    function openPairingSettings() {
        if (root.visible && panel.opened && panel.currentView === "Devices" && !panel.editingLayout
                && handoffAvailable && service && !service.nativeAppOpening) service.openPairingSettings()
    }

    property Item pickerReturnFocus: null

    function openDevicePicker(returnFocus) {
        if (!devicePicker.enabled || devicePicker.popup.visible) return
        pickerReturnFocus = returnFocus
        devicePicker.forceActiveFocus()
        devicePicker.popup.open()
    }

    Connections {
        target: devicePicker.popup
        function onClosed() {
            var returnFocus = root.pickerReturnFocus
            root.pickerReturnFocus = null
            if (returnFocus && root.panel.opened && root.panel.currentView === "Devices"
                    && !root.panel.editingLayout && devicePicker.activeFocus) {
                returnFocus.forceActiveFocus(Qt.PopupFocusReason)
            }
        }
    }

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
            tooltipText: Locale.Strings.t("device.refreshDiscoveryHelp")
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: Locale.Strings.t("device.refreshDevices")
            Accessible.description: Locale.Strings.t("device.refreshDiscoveryHelp")
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
            tooltipText: Locale.Strings.t("device.plusDeviceSettings")
            Accessible.role: Accessible.Button
            Accessible.name: Locale.Strings.t("device.plusDeviceSettings")
            Accessible.description: Locale.Strings.t("device.openThisDeviceSPlusSettings")
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
            tooltipText: Locale.Strings.t("device.dismissDeviceStatus")
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: Locale.Strings.t("device.dismissDeviceStatus")
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

    Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.handoffAvailable || !!(root.service && root.service.nativeAppFailed)
        Text {
            objectName: "partial-roster-warning"
            width: parent.width
            visible: root.partialRoster
            text: Locale.Strings.t("kde.status.partialRoster")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.foreground
            font.family: root.fontFamily
        }
        Text {
            objectName: "incoming-pairing-warning"
            width: parent.width
            visible: !!root.incomingRequest
            text: root.incomingRequest ? Locale.Strings.format("device.pairingFrom", [devicePicker.disambiguatedName(root.incomingRequest)]) : ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.foreground
            font.family: root.fontFamily
            font.bold: true
        }
        Text {
            width: parent.width
            visible: !!root.incomingRequest
            text: Locale.Strings.t(root.incomingRequest && root.incomingRequest.verificationKey ? "device.verifyInNative" : "device.keyUnavailable")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.foreground
            font.family: root.fontFamily
        }
        Text {
            width: parent.width
            visible: !!root.outgoingRequest
            text: root.outgoingRequest ? Locale.Strings.format("device.waitForPairingPeer", [devicePicker.disambiguatedName(root.outgoingRequest)]) : ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.foreground
            font.family: root.fontFamily
        }
        Button {
            objectName: "pairing-native-handoff"
            visible: root.handoffAvailable
            enabled: !!root.service && !root.service.nativeAppOpening
            height: Math.max(44, implicitHeight)
            focusable: true
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            text: Locale.Strings.t(root.pairAvailable && root.device.requestKnown !== false && !root.incomingRequest && !root.outgoingRequest
                ? "device.pairInKdeConnect" : "device.openKdeConnect")
            Accessible.role: Accessible.Button
            Accessible.name: text
            tooltipText: Locale.Strings.t("device.pairingHandoffHelp")
            Accessible.description: tooltipText
            Accessible.onPressAction: if (visible && enabled) clicked()
            onClicked: root.openPairingSettings()
        }
        Text {
            width: parent.width
            visible: !!(root.service && root.service.nativeAppMessage)
            text: root.service ? root.service.nativeAppMessage + (root.service.nativeAppFailed
                ? " " + Locale.Strings.t("device.openFromLauncher") : "") : ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.service && root.service.nativeAppFailed ? Commons.Color.urgent : root.foreground
            font.family: root.fontFamily
        }
    }

    Column {
        objectName: "device-unpair-confirmation"
        width: parent.width
        visible: root.isUnpairConfirming
        spacing: Style.space(4)
        Text {
            width: parent.width
            text: Locale.Strings.t("device.removeKdeConnectPairingConfirmOnly")
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
                text: Locale.Strings.t("device.confirmUnpair")
                bordered: true
                height: Math.max(44, implicitHeight)
                selected: true
                focusable: true
                Accessible.role: Accessible.Button
                Accessible.name: Locale.Strings.t("device.confirmUnpairSelectedDevice")
                Accessible.onPressAction: if (visible && enabled) clicked()
                foreground: Commons.Color.urgent
                accent: Commons.Color.urgent
                fontFamily: root.fontFamily
                onClicked: if (root.device) panel.confirmUnpair(root.device.id)
            }
            Button {
                text: Locale.Strings.t("common.cancel")
                bordered: true
                height: Math.max(44, implicitHeight)
                focusable: true
                Accessible.role: Accessible.Button
                Accessible.name: Locale.Strings.t("device.cancelUnpairSelectedDevice")
                Accessible.onPressAction: if (visible && enabled) clicked()
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: if (root.device) panel.cancelUnpairConfirm(root.device.id)
            }
        }
    }
    Text {
        width: parent.width
        visible: root.unpairPending
        text: Locale.Strings.t("device.unpairing")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
    }

    // One region for everything about the selected device, styled like the other sections.
    DailySection {
        sectionId: "devices"
        visible: root.showDetails && !!root.device
        title: Locale.Strings.t("device.deviceDetails")
        description: Locale.Strings.t("device.batteryNetworkIdAndPairingFor")
        expanded: root.detailsExpanded
        onToggleRequested: root.detailsToggleRequested()
        Column {
            objectName: "selected-device-details"
            width: parent.width
            spacing: Style.space(6)
            DeviceInformationSection {
                width: parent.width
                service: root.service
                showTitle: false
                compact: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                showBattery: root.showBattery
                showCellular: root.showNetwork
            }
            Flow {
                width: parent.width
                spacing: Style.space(4)
                Button {
                    visible: !!(root.device && root.service && root.service.discoveryOwner && root.device.paired
                        && root.device.pairingReported === true && !root.isUnpairConfirming && !root.unpairPending)
                    text: Locale.Strings.t("device.unpair")
                    bordered: true
                    height: Math.max(44, implicitHeight)
                    focusable: true
                    Accessible.role: Accessible.Button
                    Accessible.name: Locale.Strings.t("device.unpairSelectedDevice")
                    Accessible.onPressAction: if (visible && enabled) clicked()
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
                if (root.service && root.service.scanning) return Locale.Strings.t("device.scanning")
                if (root.service && root.service.discoveryState === "not_installed") return Locale.Strings.t("device.packagesMissing")
                if (root.partialRoster) return ""
                if (root.service && root.service.discoveryState === "unavailable") return Locale.Strings.t("device.daemonUnavailable")
                return Locale.Strings.t("device.noDevices")
            }
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
        }

        Text {
            width: parent.width
            text: root.service && root.service.discoveryState === "not_installed"
                ? Locale.Strings.t("device.runThisCommandInATerminal")
                : Locale.Strings.t("device.pairDevicesInKdeConnectThe")
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
            Accessible.name: Locale.Strings.t("device.kdeConnectInstallCommandFocusAnd")
            onActiveFocusChanged: if (activeFocus) selectAll()
        }
        Button {
            height: Math.max(44, implicitHeight)
            text: Locale.Strings.t("device.kdeConnectSetupGuide")
            bordered: true
            Accessible.role: Accessible.Button
            Accessible.name: Locale.Strings.t("device.openTheOfficialKdeConnectSetup")
            Accessible.onPressAction: if (enabled) clicked()
            focusable: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: Qt.openUrlExternally("https://kdeconnect.kde.org/users.html")
        }

    }
}
