pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../i18n" as Locale

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
        text: Locale.Strings.t("deviceInformation.information")
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
    }
    function reportedStats(showBattery, showCellular) {
        return current && service && typeof service.deviceBatteryText === "function"
            ? service.deviceBatteryText(device, showBattery, showCellular) : ""
    }

    Repeater {
        model: [
            {id: "id", value: root.device ? root.device.id : Locale.Strings.t("deviceInformation.chooseDevice")},
            {id: "battery", value: root.reportedStats(true, false), shown: root.showBattery},
            {id: "cellular", value: root.reportedStats(false, true), shown: root.showCellular},
            {id: "addresses", value: root.device && root.current ? (root.device.reachableAddresses || []).join(", ") : "", needsConnection: true},
            {id: "providers", value: root.device && root.current ? (root.device.activeProviderNames || []).join(", ") : "", needsConnection: true}
        ]
        delegate: Text {
            required property var modelData
            objectName: "device-information-" + modelData.id
            width: root.width
            visible: modelData.shown !== false && (!root.compact || !!modelData.value)
            text: Locale.Strings.format("deviceInformation.field", [
                Locale.Strings.t("deviceInformation." + modelData.id),
                modelData.value || (modelData.needsConnection && !root.current
                    ? Locale.Strings.t("deviceInformation.offline") : Locale.Strings.t("deviceInformation.notReported"))
            ])
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
        }
    }
}
