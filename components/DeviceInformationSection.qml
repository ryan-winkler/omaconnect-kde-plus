pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons

Column {
    id: root
    required property var service
    readonly property var device: service ? service.selectedDevice : null
    property bool showTitle: true
    property bool showBattery: true
    property bool showCellular: true
    // Compact rows skip values the device did not report.
    property bool compact: false
    property color foreground: Commons.Color.popups.text
    property string fontFamily: Style.font.family
    readonly property bool current: !!(device && device.paired && device.reachable)
    width: parent ? parent.width : 0
    spacing: Style.space(6)
    Text {
        visible: root.showTitle
        text: "Information"
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
    }
    Repeater {
        model: [
            {label: "Device ID", value: root.device ? root.device.id : "Choose a device"},
            {label: "Battery", value: root.current && root.service && typeof root.service.deviceBatteryText === "function" ? root.service.deviceBatteryText(root.device, true, false) || "Not reported" : "Not reported", shown: root.showBattery},
            {label: "Cellular", value: root.current && root.service && typeof root.service.deviceBatteryText === "function" ? root.service.deviceBatteryText(root.device, false, true) || "Not reported" : "Not reported", shown: root.showCellular},
            {label: "Addresses", value: !root.device || !root.current ? "Unavailable while offline or not paired" : (root.device.reachableAddresses || []).join(", ") || "Not reported"},
            {label: "Connection providers", value: !root.device || !root.current ? "Unavailable while offline or not paired" : (root.device.activeProviderNames || []).join(", ") || "Not reported"}
        ]
        delegate: Text {
            required property var modelData
            objectName: "device-information-" + modelData.label
            width: root.width
            visible: modelData.shown !== false && !(root.compact && (modelData.value === "Not reported" || modelData.value.indexOf("Unavailable") === 0))
            text: modelData.label + ": " + modelData.value
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
        }
    }
}
