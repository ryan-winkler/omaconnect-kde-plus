pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Column {
    id: root
    required property var service
    readonly property var device: service ? service.selectedDevice : null
    property bool expanded: false
    readonly property var pluginIds: device && device.pluginIds ? device.pluginIds : []
    // IDs remain visible even when this version has no friendly task label.
    function taskName(id) {
        var tasks = {
            kdeconnect_battery: "Check battery", kdeconnect_ping: "Send a ping",
            kdeconnect_share: "Share files, text and links", kdeconnect_clipboard: "Share clipboard",
            kdeconnect_findmyphone: "Ring the other device", kdeconnect_findthisdevice: "Let the other device ring this computer",
            kdeconnect_notifications: "View notifications from the other device", kdeconnect_sendnotifications: "Send this computer's notifications",
            kdeconnect_replynotifications: "Reply to notifications", kdeconnect_sftp: "Browse the other device's files",
            kdeconnect_mprisremote: "Control the other device's media", kdeconnect_mpriscontrol: "Let the other device control this computer's media",
            kdeconnect_remotecommands: "Run commands on the other device", kdeconnect_runcommand: "Choose commands the other device can run here",
            kdeconnect_mousepad: "Let the other device control this computer's input", kdeconnect_remotekeyboard: "Type on the other device",
            kdeconnect_presenter: "Use presentation controls", kdeconnect_sms: "Send and read SMS",
            kdeconnect_contacts: "Use shared contacts", kdeconnect_lockdevice: "Device locking",
            kdeconnect_connectivity_report: "Check cellular connection", kdeconnect_telephony: "Handle call events",
            kdeconnect_pausemusic: "Pause media during calls", kdeconnect_systemvolume: "System volume",
            kdeconnect_remotesystemvolume: "Volume controls", kdeconnect_shareinputdevices: "Share input devices"
        }
        return tasks[id] || "Native KDE Connect feature"
    }
    width: parent ? parent.width : 0
    spacing: Style.space(6)
    Kit.Button {
        width: parent.width
        text: "All KDE Connect features"
        Accessible.name: text
        Accessible.description: "Open the selected device in KDE Connect. Use Plugin settings to choose its native features and permissions."
        focusable: true
        enabled: !!root.service
        onClicked: if (root.service) root.service.openKdeConnectApp()
    }
    Text {
        width: parent.width
        text: "Open the selected device in KDE Connect for more tasks and Plugin settings. Features depend on both devices and permissions."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Kit.Button {
        width: parent.width
        text: root.expanded ? "Hide feature support details" : "Feature support details"
        Accessible.name: text
        focusable: true
        enabled: !!root.device
        onClicked: root.expanded = !root.expanded
    }
    Column {
        width: parent.width
        visible: root.expanded && !!root.device
        spacing: Style.space(6)
        Text {
            width: parent.width
            text: "Supported means compatible with this device. Loaded means active in the local daemon now. Neither proves permission or that a task will succeed. Change enabled features in native Plugin settings. If the older settings app opens, select your device there."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.pixelSize: Style.font.caption
        }
        Text {
            width: parent.width
            visible: root.pluginIds.length === 0
            text: "No supported feature list is available. Open KDE Connect to inspect this device."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
        }
        Repeater {
            model: root.pluginIds
            delegate: Text {
                required property string modelData
                width: parent.width
                text: root.taskName(modelData) + "\n" + modelData + " · Supported · "
                    + (!root.device.loadedKnown ? "Loading status unknown" : root.device.loadedPluginIds.indexOf(modelData) !== -1 ? "Loaded" : "Not loaded")
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: Commons.Color.popups.text
                font.pixelSize: Style.font.caption
            }
        }
    }
}
