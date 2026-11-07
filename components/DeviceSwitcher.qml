pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit
import "../i18n" as Locale

// Native selection and identity labels shared by daily and settings views.
Controls.ComboBox {
    required property var panel
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    readonly property var devices: service ? service.devices : []
    readonly property string selectedId: device ? device.id : ""
    readonly property var deviceOptions: devices.map(function(entry) {
        var displayName = root.disambiguatedName(entry)
        var state = root.deviceState(entry)
        return {value: entry.id, name: displayName, state: state, type: entry.type,
            active: entry.paired && entry.reachable, label: displayName + " · " + state}
    })
    readonly property string deviceStatus: {
        if (!service) return Locale.Strings.t("deviceSwitcher.kdeConnectIsUnavailableOpenKde")
        if (devices.length === 0) {
            if (service.discoveryState === "partial") return service.discoveryMessage
            if (service.scanning || service.discoveryState === "starting") return Locale.Strings.t("deviceSwitcher.checkingKdeConnectForDevices")
            if (!service.daemonAvailable) return service.discoveryMessage || Locale.Strings.t("deviceSwitcher.kdeConnectIsUnavailableOpenIt")
            return Locale.Strings.t("deviceSwitcher.noDevicesFoundOpenKdeConnect")
        }
        if (!device) return Locale.Strings.t("deviceSwitcher.chooseADeviceAbove")
        return Locale.Strings.format("deviceSwitcher.selectionStatus", [root.deviceState(device)])
    }
    readonly property string deviceOptionsKey: JSON.stringify(deviceOptions.map(function(option) {
        return [option.value, option.label]
    }))
    property bool popupInvalidated: false
    onDeviceOptionsKeyChanged: {
        if (popup && popup.visible) {
            popupInvalidated = true
            popup.close()
        }
    }
    Connections {
        target: root.popup
        function onAboutToShow() {
            rosterNotice.close()
            root.popupInvalidated = false
        }
        function onClosed() {
            if (root.popupInvalidated && root.visible) rosterNotice.open()
        }
    }
    readonly property color surfaceColor: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    signal aboutToSelect(string deviceId)

    function deviceName(entry) {
        return service && typeof service.displayName === "function" ? service.displayName(entry) : entry.name
    }
    function disambiguatedName(entry) {
        var name = deviceName(entry)
        var duplicate = devices.some(function(other) { return other.id !== entry.id && root.deviceName(other) === name })
        return name + (duplicate ? " [" + entry.id + "]" : "")
    }
    function deviceState(entry) {
        if (entry.pairingKnown === false || entry.reachabilityKnown === false) return Locale.Strings.t("deviceSwitcher.statusUnavailable")
        return !entry.paired ? Locale.Strings.t("deviceSwitcher.notPaired") : entry.reachable ? Locale.Strings.t("deviceSwitcher.connected") : Locale.Strings.t("deviceSwitcher.offline")
    }
    function selectDevice(id) {
        // Resolve the stable ID again: discovery may replace or reorder the list.
        if (!panel || !devices.some(function(entry) { return entry.id === id }) || (device && device.id === id)) return
        aboutToSelect(id)
        panel.selectDevice(id)
    }
    id: root
    width: parent.width
    height: Math.max(44, Style.spacing.controlHeight)
    leftPadding: Style.spacing.controlPaddingX
    rightPadding: Style.spacing.controlGap + chevron.width + Style.spacing.md
    model: root.deviceOptions
    textRole: "label"
    valueRole: "value"
    currentValue: root.selectedId
    readonly property var selectedOption: deviceOptions.find(function(option) { return option.value === root.selectedId })
    displayText: selectedOption ? selectedOption.label : Locale.Strings.t("deviceSwitcher.choose")
    enabled: root.devices.length > 0
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    palette.text: Commons.Color.popups.text
    palette.buttonText: Commons.Color.popups.text
    palette.button: root.surfaceColor
    palette.base: root.surfaceColor
    palette.window: root.surfaceColor
    palette.highlight: Commons.Color.accent
    palette.highlightedText: root.surfaceColor
    Accessible.role: Accessible.ComboBox
    Accessible.name: Locale.Strings.t("settings.device")
    Accessible.description: (root.selectedOption ? root.selectedOption.name + ". " + root.deviceStatus : root.deviceStatus)
        + (rosterNotice.visible ? " " + rosterNotice.text : "")
    Accessible.onPressAction: {
        if (!enabled) return
        forceActiveFocus()
        popup.visible ? popup.close() : popup.open()
    }
    onVisibleChanged: if (!visible) rosterNotice.close()
    Kit.PanelToolTip {
        id: rosterNotice
        objectName: "device-list-refresh-notice"
        text: Locale.Strings.t(root.enabled ? "deviceSwitcher.reopenChangedList" : "deviceSwitcher.changedListEmpty")
        x: 0
        y: root.height + Style.spacing.controlGap
        width: Math.min(root.width, implicitWidth)
        delay: 0
        timeout: 6500
        focus: false
        closePolicy: Controls.Popup.NoAutoClose
        onOpened: root.Accessible.announce(text, Accessible.Polite)
    }
    component DeviceLabel: RowLayout {
        id: row
        property var option
        spacing: Style.space(6)
        AppearanceIcon {
            readonly property var appearance: root.service && "appearance" in root.service ? root.service.appearance : null
            readonly property bool hasIcon: !!(row.option && appearance && typeof appearance.deviceIcon === "function")
            Layout.preferredWidth: Style.space(20)
            Layout.preferredHeight: Style.space(20)
            opacity: hasIcon ? 1 : 0
            icon: hasIcon ? appearance.deviceIcon(row.option.value, row.option.type) : ({mode: "preset", value: "phone"})
            assetBaseUrl: hasIcon && typeof appearance.assetBaseUrl === "string" ? appearance.assetBaseUrl : ""
            foreground: row.option && row.option.active ? Commons.Color.accent : Commons.Color.popups.text
            fontFamily: root.font.family
        }
        Text {
            objectName: "device-label-name"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: row.option ? row.option.name : Locale.Strings.t("deviceSwitcher.choose")
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font: root.font
            elide: Text.ElideMiddle
        }
        Text {
            visible: !!row.option
            Layout.maximumWidth: Math.floor(row.width * 0.48)
            text: row.option ? row.option.state : ""
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font: root.font
            elide: Text.ElideRight
        }
    }
    contentItem: DeviceLabel { option: root.selectedOption }
    // Same chevron and hover fill as the Omarchy Dropdown.
    indicator: Text {
        id: chevron
        x: root.width - width - Style.spacing.controlGap
        y: (root.height - height) / 2
        text: "󰅀"
        textFormat: Text.PlainText
        color: Qt.darker(Commons.Color.popups.text, 1.2)
        font.family: root.font.family
        font.pixelSize: Style.font.body
    }
    background: Rectangle {
        color: Style.controlFill(root.activeFocus, root.enabled && root.hovered, Commons.Color.popups.text, Commons.Color.accent)
        radius: Style.cornerRadius
        border.width: root.activeFocus ? 2 : Style.normalBorderWidth
        border.color: root.activeFocus ? Commons.Color.accent : Commons.Color.popups.border
    }
    delegate: Controls.ItemDelegate {
        id: optionDelegate
        required property var modelData
        required property int index
        objectName: "device-option-" + index
        text: modelData.label
        Accessible.name: text
        Accessible.onPressAction: if (enabled && root.popup.visible) clicked()
        width: root.width
        leftPadding: root.leftPadding
        rightPadding: root.rightPadding
        height: root.height
        highlighted: root.highlightedIndex === index
        contentItem: DeviceLabel { option: optionDelegate.modelData }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.controlGap
            anchors.verticalCenter: parent.verticalCenter
            visible: !!optionDelegate.modelData && optionDelegate.modelData.value === root.selectedId
            text: "✓"
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font: root.font
            Accessible.ignored: true
        }
        background: Rectangle {
            color: parent.highlighted ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : root.surfaceColor
        }
    }
    onActivated: function(index) {
        if (root.popupInvalidated) {
            // A closed ComboBox can move its native index before emitting activated.
            root.currentIndex = root.indexOfValue(root.selectedId)
            return
        }
        var option = root.deviceOptions[index]
        if (option) root.selectDevice(option.value)
    }
}
