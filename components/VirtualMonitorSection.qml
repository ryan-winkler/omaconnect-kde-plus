pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../ActionCatalog.js" as Actions
import "../i18n" as Locale

Column {
    id: root
    required property var service
    property bool configuration: false
    readonly property var device: service ? service.selectedDevice : null
    readonly property bool reported: !!device && (device.pluginIds || []).indexOf("kdeconnect_virtualmonitor") !== -1
    readonly property var monitor: device && device.virtualMonitor ? device.virtualMonitor : ({known:false,active:false,available:false})
    visible: configuration || reported
    width: parent ? parent.width : 0
    spacing: Style.space(6)
    SettingsButton {
        objectName: "virtual-monitor-action"
        width: parent.width
        height: Math.max(44, implicitHeight)
        text: Locale.Strings.t(Actions.actionLabelKey("external-monitor", root.device))
        Accessible.name: text
        Accessible.description: Locale.Strings.t("virtualMonitor.useKdeConnectSNativeVirtual")
        focusable: true
        enabled: Actions.ready("external-monitor", root.device, root.service)
        foreground: Commons.Color.popups.text
        onClicked: if (enabled) root.service.toggleVirtualMonitor(root.device.id)
    }
    Text {
        width: parent.width
        text: !Actions.ready("external-monitor", root.device, root.service) ? Locale.Strings.t(Actions.availabilityKey("external-monitor", root.device, root.service))
            : root.monitor.active ? Locale.Strings.t("virtualMonitor.active")
            : Locale.Strings.t("virtualMonitor.nativeHelp")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Text {
        width: parent.width
        visible: text !== ""
        text: root.service && (root.service.actionError || root.service.actionMessage) ? Locale.Strings.format("nativeFeatures.latestAction", [root.service.actionError || root.service.actionMessage]) : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
}
