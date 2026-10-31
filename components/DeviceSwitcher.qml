pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons

// Native selection and identity labels shared by daily and settings views.
Controls.ComboBox {
    required property var panel
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    readonly property var devices: service ? service.devices : []
    readonly property string selectedId: device ? device.id : ""
    readonly property var deviceOptions: devices.map(function(entry) {
        var name = root.deviceName(entry)
        var duplicate = root.devices.some(function(other) { return other.id !== entry.id && root.deviceName(other) === name })
        return {value: entry.id, label: name + (duplicate ? " [" + entry.id + "]" : "") + " · " + root.deviceState(entry)}
    })
    readonly property string deviceStatus: {
        if (!service) return "KDE Connect is unavailable. Open KDE Connect to check its setup."
        if (devices.length === 0) {
            if (service.scanning || service.discoveryState === "starting") return "Checking KDE Connect for devices…"
            if (!service.daemonAvailable) return service.discoveryMessage || "KDE Connect is unavailable. Open it to check its setup."
            return "No devices found. Open KDE Connect to pair a device."
        }
        if (!device) return "Choose a device above."
        return root.deviceState(device) + ". Switching also changes the device in Devices."
    }
    readonly property string deviceOptionsKey: JSON.stringify(deviceOptions)
    onDeviceOptionsKeyChanged: if (popup) popup.close()
    readonly property color surfaceColor: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    signal aboutToSelect(string deviceId)

    function deviceName(entry) {
        return service && typeof service.displayName === "function" ? service.displayName(entry) : entry.name
    }
    function deviceState(entry) {
        return !entry.paired ? "Not paired" : entry.reachable ? "Connected" : "Offline"
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
    model: root.deviceOptions
    textRole: "label"
    valueRole: "value"
    currentValue: root.selectedId
    displayText: {
        var options = root.deviceOptions
        var selected = options.find(function(option) { return option.value === root.selectedId })
        return selected ? selected.label : "Choose a device"
    }
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
    Accessible.name: "Device"
    Accessible.description: root.deviceStatus
    Accessible.onPressAction: {
        if (!enabled) return
        forceActiveFocus()
        popup.visible ? popup.close() : popup.open()
    }
    contentItem: Text {
        text: root.displayText
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font: root.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        leftPadding: selectedIcon.visible ? selectedIcon.width + Style.space(6) : 0
        AppearanceIcon {
            id: selectedIcon
            visible: !!(root.device && root.service && "appearance" in root.service && root.service.appearance && typeof root.service.appearance.deviceIcon === "function")
            width: Style.space(20)
            height: width
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: visible ? root.service.appearance.deviceIcon(root.device.id, root.device.type) : ({mode:"preset",value:"phone"})
            assetBaseUrl: visible && typeof root.service.appearance.assetBaseUrl === "string" ? root.service.appearance.assetBaseUrl : ""
            foreground: root.device && root.device.paired && root.device.reachable ? Commons.Color.accent : Commons.Color.popups.text
            fontFamily: root.font.family
        }
    }
    background: Rectangle {
        color: root.surfaceColor
        radius: Style.cornerRadius
        border.width: root.activeFocus ? 2 : Style.normalBorderWidth
        border.color: root.activeFocus ? Commons.Color.accent : Commons.Color.popups.border
    }
    delegate: Controls.ItemDelegate {
        required property var modelData
        required property int index
        objectName: "device-option-" + index
        text: modelData.label
        Accessible.name: text
        Accessible.onPressAction: if (enabled && root.popup.visible) clicked()
        width: root.width
        height: Math.max(44, implicitHeight)
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: modelData.label
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font: root.font
            wrapMode: Text.Wrap
        }
        background: Rectangle {
            color: parent.highlighted ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : root.surfaceColor
        }
    }
    onActivated: function(index) {
        var option = root.deviceOptions[index]
        if (option) root.selectDevice(option.value)
    }
}
