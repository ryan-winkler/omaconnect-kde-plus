pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit
import "../ActionCatalog.js" as Actions

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
    Kit.Button {
        objectName: "virtual-monitor-action"
        width: parent.width
        height: Math.max(44, implicitHeight)
        text: Actions.actionLabel("external-monitor", root.device)
        Accessible.name: text
        Accessible.description: "Use KDE Connect's native virtual display. KDE Connect handles its session and credentials."
        focusable: true
        enabled: Actions.ready("external-monitor", root.device, root.service)
        foreground: Commons.Color.popups.text
        onClicked: if (enabled) root.service.toggleVirtualMonitor(root.device.id)
    }
    Text {
        width: parent.width
        text: !Actions.ready("external-monitor", root.device, root.service) ? Actions.availabilityText("external-monitor", root.device, root.service)
            : root.monitor.active ? "Native virtual monitor session is active on this computer. Remote display output is not confirmed."
            : "Uses native KDE Connect and KRDP. The other device needs an RDP client."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Text {
        width: parent.width
        visible: text !== ""
        text: root.service && (root.service.actionError || root.service.actionMessage) ? "Latest device action: " + (root.service.actionError || root.service.actionMessage) : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
}
